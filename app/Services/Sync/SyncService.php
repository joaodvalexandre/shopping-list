<?php

namespace App\Services\Sync;

use App\Enums\ListAbility;
use App\Models\Item;
use App\Models\ListType;
use App\Models\ShoppingList;
use App\Models\Status;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Two-way sync between a device and the server in one round trip:
 * the device pushes what changed offline, the server applies it and answers
 * with everything the device needs to catch up.
 *
 * Rules:
 *  - Everything goes through the same permissions as the web app
 *    (ShoppingListPolicy, ShoppingList::visibleTo): a device can never push
 *    to, or pull from, a list its user cannot see.
 *  - Conflicts resolve per field, last write wins: a pushed field only
 *    overwrites the server's value if its timestamp is newer.
 *  - Deletions win over edits (soft-deleted rows stay as tombstones).
 *  - Client clocks are not trusted blindly: timestamps in the future are
 *    clamped to the server's "now".
 */
class SyncService
{
    /** Pull cursors are rewound by this much so a slow concurrent write is never missed. */
    private const CURSOR_OVERLAP_SECONDS = 5;

    /** How far ahead of the server a device clock may run before it is clamped. */
    private const MAX_CLOCK_SKEW_SECONDS = 300;

    /**
     * @param  array{since?: ?string, known_lists?: list<string>, changes?: array}  $payload  validated request
     */
    public function sync(User $user, array $payload): array
    {
        $now = Carbon::now();
        $statusIds = Status::pluck('id', 'code');
        $results = ['lists' => [], 'items' => []];

        DB::transaction(function () use ($user, $payload, $now, $statusIds, &$results) {
            foreach ($payload['changes']['lists'] ?? [] as $change) {
                $results['lists'][$change['uuid']] = $this->applyList($user, $change, $now);
            }

            foreach ($payload['changes']['items'] ?? [] as $change) {
                $results['items'][$change['uuid']] = $this->applyItem($user, $change, $now, $statusIds);
            }
        });

        $since = isset($payload['since']) ? Carbon::parse($payload['since']) : null;

        return [
            'server_time' => $this->time($now->copy()->subSeconds(self::CURSOR_OVERLAP_SECONDS)),
            'results' => $results,
            ...$this->pull($user, $since, $payload['known_lists'] ?? [], $statusIds->flip()),
            'me' => $this->profile($user),
        ];
    }

    // ------------------------------------------------------------------ push

    private function applyList(User $user, array $change, Carbon $now): array
    {
        $existing = ShoppingList::withTrashed()->where('uuid', $change['uuid'])->first();

        // A uuid that belongs to another family looks exactly like an invalid one
        if ($existing && (int) $existing->family_id !== (int) $user->family_id) {
            return $this->rejected('invalid');
        }

        if (! $existing) {
            if (! empty($change['deleted_at'])) {
                return $this->ignored('unknown'); // created and deleted while offline
            }

            $type = ListType::where('family_id', $user->family_id)->find($change['list_type_id'] ?? null);
            if (! $type || blank($change['name'] ?? null)) {
                return $this->rejected('invalid');
            }
            if (! $user->can('create', [ShoppingList::class, $type])) {
                return $this->rejected('forbidden');
            }

            $list = ShoppingList::create([
                'uuid' => $change['uuid'],
                'name' => $change['name'],
                'name_changed_at' => $this->clamp($change['name_changed_at'] ?? null, $now),
                'family_id' => $user->family_id,
                'list_type_id' => $type->id,
                'created_by' => $user->id,
            ]);
            $this->syncHidden($list, $user, $change['hidden_from'] ?? []);

            return $this->applied();
        }

        if ($existing->trashed()) {
            return $this->ignored('deleted');
        }

        // Lists the user cannot see do not exist as far as they are concerned
        if (! ShoppingList::visibleTo($user)->whereKey($existing->id)->exists()) {
            return $this->rejected('not_found');
        }

        if (! empty($change['deleted_at'])) {
            if (! $user->can('delete', $existing)) {
                return $this->rejected('forbidden');
            }
            $existing->delete();

            return $this->applied();
        }

        $rejected = [];

        if (array_key_exists('name', $change)) {
            if (! $user->can('update', $existing)) {
                $rejected[] = 'name';
            } elseif ($this->isNewer($change['name_changed_at'] ?? null, $existing->name_changed_at, $now)) {
                $existing->update([
                    'name' => $change['name'],
                    'name_changed_at' => $this->clamp($change['name_changed_at'] ?? null, $now),
                ]);
            }
        }

        if (array_key_exists('hidden_from', $change)) {
            if ($user->can('update', $existing)) {
                $this->syncHidden($existing, $user, $change['hidden_from'] ?? []);
            } else {
                $rejected[] = 'hidden_from';
            }
        }

        return $rejected ? $this->rejected('forbidden', $rejected) : $this->applied();
    }

    private function applyItem(User $user, array $change, Carbon $now, Collection $statusIds): array
    {
        $existing = Item::withTrashed()->where('uuid', $change['uuid'])->first();

        if ($existing) {
            $familyId = ShoppingList::withTrashed()->whereKey($existing->shopping_list_id)->value('family_id');
            if ((int) $familyId !== (int) $user->family_id) {
                return $this->rejected('invalid');
            }
        }

        $list = ShoppingList::visibleTo($user)->where('uuid', $change['list_uuid'])->first();
        if (! $list) {
            return $this->rejected('not_found');
        }
        if ($existing && $existing->shopping_list_id !== $list->id) {
            return $this->rejected('invalid'); // items never move between lists
        }

        if (! $existing) {
            if (! empty($change['deleted_at'])) {
                return $this->ignored('unknown');
            }
            if (! $user->can('addItems', $list)) {
                return $this->rejected('forbidden');
            }
            if (blank($change['name'] ?? null)) {
                return $this->rejected('invalid');
            }

            // Moving through the cart needs its own permission; anyone who can add may only add
            $canChangeStatus = $user->can('changeStatus', $list);
            $status = $canChangeStatus ? ($change['status'] ?? 'to_buy') : 'to_buy';

            Item::create([
                'uuid' => $change['uuid'],
                'shopping_list_id' => $list->id,
                'name' => $change['name'],
                'quantity' => $change['quantity'] ?? 1,
                'status_id' => $statusIds[$status] ?? $statusIds['to_buy'],
                'name_changed_at' => $this->clamp($change['name_changed_at'] ?? null, $now),
                'quantity_changed_at' => $this->clamp($change['quantity_changed_at'] ?? null, $now),
                'status_changed_at' => $this->clamp($change['status_changed_at'] ?? null, $now),
            ]);

            return $this->applied();
        }

        if ($existing->trashed()) {
            return $this->ignored('deleted');
        }

        if (! empty($change['deleted_at'])) {
            if (! $user->can('editItems', $list)) {
                return $this->rejected('forbidden');
            }
            // Someone put it in the cart meanwhile: it is about to be bought, so it stays
            if ($existing->isInCart()) {
                return $this->rejected('in_cart');
            }
            $existing->delete();

            return $this->applied();
        }

        $rejected = [];

        foreach (['name' => 'name', 'quantity' => 'quantity'] as $field => $column) {
            if (! array_key_exists($field, $change)) {
                continue;
            }
            if (! $user->can('editItems', $list)) {
                $rejected[] = $field;
            } elseif ($this->isNewer($change["{$field}_changed_at"] ?? null, $existing->{"{$field}_changed_at"}, $now)) {
                $existing->{$column} = $change[$field];
                $existing->{"{$field}_changed_at"} = $this->clamp($change["{$field}_changed_at"] ?? null, $now);
            }
        }

        if (array_key_exists('status', $change)) {
            if (! $user->can('changeStatus', $list)) {
                $rejected[] = 'status';
            } elseif ($this->isNewer($change['status_changed_at'] ?? null, $existing->status_changed_at, $now)) {
                $existing->status_id = $statusIds[$change['status']];
                $existing->status_changed_at = $this->clamp($change['status_changed_at'] ?? null, $now);
            }
        }

        $existing->save();

        return $rejected ? $this->rejected('forbidden', $rejected) : $this->applied();
    }

    // ------------------------------------------------------------------ pull

    /**
     * @param  list<string>  $known  uuids of the lists the device already holds
     */
    private function pull(User $user, ?Carbon $since, array $known, Collection $statusCodes): array
    {
        $visible = ShoppingList::visibleTo($user)->get();
        $newToDevice = $visible->reject(fn (ShoppingList $list) => in_array($list->uuid, $known, true));

        // Lists the device has never seen (just granted, just unhidden) are sent whole,
        // whatever their age: the cursor alone would never deliver them.
        $lists = $visible->filter(
            fn (ShoppingList $list) => $since === null
                || $list->updated_at->gte($since)
                || $newToDevice->contains('id', $list->id)
        );

        // Tombstones only for lists the device says it holds
        $deletedLists = $known === [] ? collect() : ShoppingList::onlyTrashed()
            ->where('family_id', $user->family_id)
            ->whereIn('uuid', $known)
            ->get();

        $items = Item::withTrashed()
            ->whereIn('shopping_list_id', $visible->pluck('id'))
            ->where(function ($query) use ($since, $newToDevice) {
                if ($since === null) {
                    $query->whereNull('deleted_at');

                    return;
                }

                $query->where('updated_at', '>=', $since)
                    ->orWhere(fn ($new) => $new->whereIn('shopping_list_id', $newToDevice->pluck('id'))->whereNull('deleted_at'));
            })
            ->get();

        $uuidById = $visible->pluck('uuid', 'id');

        return [
            'lists' => $lists->map(fn (ShoppingList $list) => $this->listPayload($list, $user))
                ->merge($deletedLists->map(fn (ShoppingList $list) => $this->listPayload($list, $user)))
                ->values()->all(),
            'items' => $items->map(fn (Item $item) => $this->itemPayload($item, $uuidById[$item->shopping_list_id], $statusCodes))
                ->values()->all(),
            // The device drops any list it holds that is not in here (hidden, revoked, or gone)
            'visible_list_uuids' => $visible->pluck('uuid')->values()->all(),
        ];
    }

    private function listPayload(ShoppingList $list, User $user): array
    {
        $payload = [
            'uuid' => $list->uuid,
            'name' => $list->name,
            'name_changed_at' => $this->time($list->name_changed_at),
            'list_type_id' => $list->list_type_id,
            'updated_at' => $this->time($list->updated_at),
            'deleted_at' => $this->time($list->deleted_at),
        ];

        // Who a list is hidden from is only revealed to those who may change it
        if (! $list->trashed() && $user->can('update', $list)) {
            $payload['hidden_from'] = $list->hiddenFrom()->pluck('users.id')->all();
        }

        return $payload;
    }

    private function itemPayload(Item $item, string $listUuid, Collection $statusCodes): array
    {
        return [
            'uuid' => $item->uuid,
            'list_uuid' => $listUuid,
            'name' => $item->name,
            'name_changed_at' => $this->time($item->name_changed_at),
            'quantity' => $item->quantity,
            'quantity_changed_at' => $this->time($item->quantity_changed_at),
            'status' => $statusCodes[$item->status_id] ?? 'to_buy',
            'status_changed_at' => $this->time($item->status_changed_at),
            'updated_at' => $this->time($item->updated_at),
            'deleted_at' => $this->time($item->deleted_at),
        ];
    }

    /**
     * Who the user is and what they may do: the device uses this to show or
     * hide the same buttons the web app does.
     */
    public function profile(User $user): array
    {
        $types = ListType::where('family_id', $user->family_id)->orderBy('name')->get();
        $managesSomething = $user->listTypeIdsWith(ListAbility::ManageLists)->isNotEmpty();

        return [
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role->value,
                'locale' => $user->locale,
                'must_change_password' => $user->must_change_password,
            ],
            'family' => ['id' => $user->family->id, 'name' => $user->family->name],
            'list_types' => $types->map(fn (ListType $type) => ['id' => $type->id, 'name' => $type->name])->all(),
            'permissions' => $types->mapWithKeys(fn (ListType $type) => [
                $type->id => collect(ListAbility::cases())
                    ->mapWithKeys(fn (ListAbility $ability) => [$ability->value => $user->canOnListType($ability, $type)])
                    ->all(),
            ])->all(),
            // Needed to offer "hide from" when creating lists; only for those who can
            'members' => $managesSomething
                ? User::where('family_id', $user->family_id)->where('id', '!=', $user->id)->orderBy('name')->get(['id', 'name'])->all()
                : [],
        ];
    }

    // --------------------------------------------------------------- helpers

    /** Only same-family members, and never the actor themselves (same rule as the web form). */
    private function syncHidden(ShoppingList $list, User $actor, array $ids): void
    {
        $list->hiddenFrom()->sync(
            User::where('family_id', $actor->family_id)->where('id', '!=', $actor->id)->whereIn('id', $ids)->pluck('id')
        );
    }

    private function clamp(?string $time, Carbon $now): Carbon
    {
        if ($time === null) {
            return $now->copy();
        }

        $parsed = Carbon::parse($time);

        return $parsed->gt($now->copy()->addSeconds(self::MAX_CLOCK_SKEW_SECONDS)) ? $now->copy() : $parsed;
    }

    private function isNewer(?string $incoming, ?Carbon $current, Carbon $now): bool
    {
        return $current === null || $this->clamp($incoming, $now)->gt($current);
    }

    private function time(?Carbon $time): ?string
    {
        return ShoppingList::apiTime($time);
    }

    private function applied(): array
    {
        return ['status' => 'applied'];
    }

    private function ignored(string $reason): array
    {
        return ['status' => 'ignored', 'reason' => $reason];
    }

    private function rejected(string $reason, array $fields = []): array
    {
        return array_filter(['status' => 'rejected', 'reason' => $reason, 'fields' => $fields]);
    }
}
