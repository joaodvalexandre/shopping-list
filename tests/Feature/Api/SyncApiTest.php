<?php

use App\Models\Item;
use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;

beforeEach(function () {
    $this->f = makeFamily();
});

function syncAs(User $user, array $payload = [])
{
    Sanctum::actingAs($user, ['sync']);

    return test()->postJson('/api/v1/sync', $payload);
}

function ago(int $seconds): string
{
    return now()->subSeconds($seconds)->utc()->format('Y-m-d\TH:i:s.v\Z');
}

// ------------------------------------------------------------------- pull

it('pulls only the lists and items the member may see', function () {
    $groceries = listIn($this->f['groceries'], ['name' => 'Weekly shop']);
    itemIn($groceries);
    $party = listIn($this->f['party'], ['name' => 'Birthday']);
    itemIn($party);
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view']);

    $response = syncAs($member)->assertOk();

    expect(collect($response->json('lists'))->pluck('name')->all())->toBe(['Weekly shop']);
    expect($response->json('items'))->toHaveCount(1)->and($response->json('items.0.list_uuid'))->toBe($groceries->uuid);
    expect($response->json('visible_list_uuids'))->toBe([$groceries->uuid]);
});

it('never pulls another family\'s data', function () {
    $other = makeFamily();
    $theirs = listIn($other['groceries'], ['name' => 'Theirs']);
    itemIn($theirs);
    listIn($this->f['groceries'], ['name' => 'Ours']);

    $response = syncAs($this->f['admin'])->assertOk();

    expect(collect($response->json('lists'))->pluck('name')->all())->toBe(['Ours']);
    expect($response->json('items'))->toBe([]);
    expect(json_encode($response->json()))->not->toContain($theirs->uuid);
});

it('keeps hidden lists out of the sync, even for admins', function () {
    $list = listIn($this->f['party'], ['name' => 'Surprise']);
    itemIn($list);
    $list->hiddenFrom()->sync([$this->f['admin']->id]);

    $response = syncAs($this->f['admin'])->assertOk();

    expect($response->json('lists'))->toBe([])->and($response->json('items'))->toBe([]);
    expect($response->json('visible_list_uuids'))->toBe([]);
});

it('tells a device to drop a list that became hidden', function () {
    $list = listIn($this->f['party']);
    $member = memberWith($this->f['family'], $this->f['party'], ['can_view']);

    expect(syncAs($member)->json('visible_list_uuids'))->toBe([$list->uuid]);

    $list->hiddenFrom()->sync([$member->id]);

    $response = syncAs($member, ['known_lists' => [$list->uuid]]);
    expect($response->json('visible_list_uuids'))->toBe([]);
});

it('delivers a list that was granted later even though it is old', function () {
    $list = listIn($this->f['groceries']);
    $item = itemIn($list);
    $list->forceFill(['updated_at' => now()->subDay()])->saveQuietly();
    $item->forceFill(['updated_at' => now()->subDay()])->saveQuietly();
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view']);

    // device synced a moment ago and knows no lists: the old list must still arrive in full
    $response = syncAs($member, ['since' => ago(10), 'known_lists' => []]);

    expect($response->json('lists'))->toHaveCount(1)->and($response->json('items'))->toHaveCount(1);

    // once the device knows it, an unchanged list is not repeated
    $again = syncAs($member, ['since' => ago(10), 'known_lists' => [$list->uuid]]);
    expect($again->json('lists'))->toBe([])->and($again->json('items'))->toBe([]);
});

it('sends only what changed since the cursor and returns a new cursor', function () {
    $list = listIn($this->f['groceries']);
    $old = itemIn($list);
    $old->forceFill(['updated_at' => now()->subHour()])->saveQuietly();
    $fresh = itemIn($list);

    $response = syncAs($this->f['admin'], ['since' => ago(60), 'known_lists' => [$list->uuid]]);

    expect(collect($response->json('items'))->pluck('uuid')->all())->toBe([$fresh->uuid]);
    expect($response->json('server_time'))->toBeString();
});

it('sends deletions as tombstones to devices that know the item or list', function () {
    $list = listIn($this->f['groceries']);
    $item = itemIn($list);
    $other = listIn($this->f['groceries']);

    $item->delete();
    $other->delete();

    $response = syncAs($this->f['admin'], ['since' => ago(60), 'known_lists' => [$list->uuid, $other->uuid]]);

    expect(collect($response->json('items'))->firstWhere('uuid', $item->uuid)['deleted_at'])->not->toBeNull();
    expect(collect($response->json('lists'))->firstWhere('uuid', $other->uuid)['deleted_at'])->not->toBeNull();
    expect($response->json('visible_list_uuids'))->toBe([$list->uuid]);
});

it('does not send tombstones of lists the device never knew', function () {
    $gone = listIn($this->f['groceries']);
    $gone->delete();

    $response = syncAs($this->f['admin'], ['since' => ago(60), 'known_lists' => []]);

    expect($response->json('lists'))->toBe([]);
});

// ------------------------------------------------------------------- push

it('creates a list and its items from offline changes', function () {
    $listUuid = (string) Str::uuid();
    $itemUuid = (string) Str::uuid();

    $response = syncAs($this->f['admin'], ['changes' => [
        'lists' => [['uuid' => $listUuid, 'name' => 'Made offline', 'list_type_id' => $this->f['groceries']->id, 'name_changed_at' => ago(30)]],
        'items' => [['uuid' => $itemUuid, 'list_uuid' => $listUuid, 'name' => 'Milk', 'quantity' => 3, 'status' => 'in_cart']],
    ]])->assertOk();

    expect($response->json("results.lists.{$listUuid}.status"))->toBe('applied')
        ->and($response->json("results.items.{$itemUuid}.status"))->toBe('applied');

    $list = ShoppingList::where('uuid', $listUuid)->firstOrFail();
    expect($list->family_id)->toBe($this->f['family']->id)
        ->and($list->created_by)->toBe($this->f['admin']->id);

    $item = Item::where('uuid', $itemUuid)->firstOrFail();
    expect($item->quantity)->toBe(3)->and($item->status_id)->toBe(2);

    // the same push twice changes nothing
    syncAs($this->f['admin'], ['changes' => [
        'lists' => [['uuid' => $listUuid, 'name' => 'Made offline', 'list_type_id' => $this->f['groceries']->id]],
    ]])->assertOk();
    expect(ShoppingList::where('uuid', $listUuid)->count())->toBe(1);
});

it('refuses to create a list without manage permission or in a foreign type', function () {
    $other = makeFamily();
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view', 'can_add_items']);
    $a = (string) Str::uuid();
    $b = (string) Str::uuid();

    $response = syncAs($member, ['changes' => ['lists' => [
        ['uuid' => $a, 'name' => 'No rights', 'list_type_id' => $this->f['groceries']->id],
    ]]]);
    expect($response->json("results.lists.{$a}.reason"))->toBe('forbidden');

    $response = syncAs($this->f['admin'], ['changes' => ['lists' => [
        ['uuid' => $b, 'name' => 'Foreign type', 'list_type_id' => $other['groceries']->id],
    ]]]);
    expect($response->json("results.lists.{$b}.reason"))->toBe('invalid');

    expect(ShoppingList::whereIn('uuid', [$a, $b])->count())->toBe(0);
});

it('lets a member who can only add items add, but not edit or move them', function () {
    $list = listIn($this->f['groceries']);
    $existing = itemIn($list);
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view', 'can_add_items']);
    $newUuid = (string) Str::uuid();

    $response = syncAs($member, ['changes' => ['items' => [
        // adding is fine - but the status asked for is ignored, they may not use the cart
        ['uuid' => $newUuid, 'list_uuid' => $list->uuid, 'name' => 'Bread', 'quantity' => 1, 'status' => 'purchased'],
        // editing / moving / deleting an existing item is not
        ['uuid' => $existing->uuid, 'list_uuid' => $list->uuid, 'name' => 'Hacked', 'name_changed_at' => ago(0), 'status' => 'purchased', 'status_changed_at' => ago(0)],
    ]]])->assertOk();

    expect($response->json("results.items.{$newUuid}.status"))->toBe('applied');
    expect(Item::where('uuid', $newUuid)->first()->status_id)->toBe(1);

    expect($response->json("results.items.{$existing->uuid}.status"))->toBe('rejected')
        ->and($response->json("results.items.{$existing->uuid}.fields"))->toBe(['name', 'status']);
    expect($existing->fresh()->name)->not->toBe('Hacked')->and($existing->fresh()->status_id)->toBe(1);

    $response = syncAs($member, ['changes' => ['items' => [
        ['uuid' => $existing->uuid, 'list_uuid' => $list->uuid, 'deleted_at' => ago(0)],
    ]]]);
    expect($response->json("results.items.{$existing->uuid}.reason"))->toBe('forbidden');
    expect(Item::find($existing->id))->not->toBeNull();
});

it('resolves conflicts per field, last write wins', function () {
    $list = listIn($this->f['groceries']);
    $item = itemIn($list);
    $item->forceFill([
        'name' => 'Server name', 'name_changed_at' => now()->subMinutes(5),
        'quantity' => 9, 'quantity_changed_at' => now()->subMinute(),
    ])->saveQuietly();

    syncAs($this->f['admin'], ['changes' => ['items' => [[
        'uuid' => $item->uuid, 'list_uuid' => $list->uuid,
        'name' => 'Phone name',  'name_changed_at' => ago(120),     // newer than the server's name (5 min ago)
        'quantity' => 2,         'quantity_changed_at' => ago(600), // older than the server's quantity (1 min ago)
    ]]]])->assertOk();

    $item = $item->fresh();
    expect($item->name)->toBe('Phone name')   // the phone won this field...
        ->and($item->quantity)->toBe(9);      // ...the server won the other
});

it('keeps the server value on an exact timestamp tie', function () {
    $list = listIn($this->f['groceries']);
    $item = itemIn($list);
    $at = now()->subMinute()->startOfSecond();
    $item->forceFill(['name' => 'Server', 'name_changed_at' => $at])->saveQuietly();

    syncAs($this->f['admin'], ['changes' => ['items' => [[
        'uuid' => $item->uuid, 'list_uuid' => $list->uuid, 'name' => 'Phone',
        'name_changed_at' => $at->copy()->utc()->format('Y-m-d\TH:i:s.v\Z'),
    ]]]]);

    expect($item->fresh()->name)->toBe('Server');
});

it('clamps timestamps from a device clock running in the future', function () {
    $list = listIn($this->f['groceries']);
    $item = itemIn($list);
    $future = now()->addYear()->utc()->format('Y-m-d\TH:i:s.v\Z');

    syncAs($this->f['admin'], ['changes' => ['items' => [[
        'uuid' => $item->uuid, 'list_uuid' => $list->uuid, 'name' => 'Time traveller', 'name_changed_at' => $future,
    ]]]]);

    $item = $item->fresh();
    expect($item->name)->toBe('Time traveller')
        ->and($item->name_changed_at->lt(now()->addMinutes(10)))->toBeTrue();
});

it('deletes through tombstones and lets deletion win over later edits', function () {
    $list = listIn($this->f['groceries']);
    $item = itemIn($list);

    syncAs($this->f['admin'], ['changes' => ['items' => [
        ['uuid' => $item->uuid, 'list_uuid' => $list->uuid, 'deleted_at' => ago(0)],
    ]]]);
    expect(Item::find($item->id))->toBeNull()->and(Item::withTrashed()->find($item->id))->not->toBeNull();

    $response = syncAs($this->f['admin'], ['changes' => ['items' => [
        ['uuid' => $item->uuid, 'list_uuid' => $list->uuid, 'name' => 'Zombie', 'name_changed_at' => ago(0)],
    ]]]);
    expect($response->json("results.items.{$item->uuid}.status"))->toBe('ignored');
    expect(Item::withTrashed()->find($item->id)->name)->not->toBe('Zombie');
});

it('rejects pushes to hidden lists as if they did not exist', function () {
    $list = listIn($this->f['party']);
    $item = itemIn($list);
    $member = memberWith($this->f['family'], $this->f['party'], ['can_view', 'can_add_items', 'can_edit_items']);
    $list->hiddenFrom()->sync([$member->id]);
    $newUuid = (string) Str::uuid();

    $response = syncAs($member, ['changes' => [
        'items' => [
            ['uuid' => $newUuid, 'list_uuid' => $list->uuid, 'name' => 'Gift'],
            ['uuid' => $item->uuid, 'list_uuid' => $list->uuid, 'deleted_at' => ago(0)],
        ],
        'lists' => [['uuid' => $list->uuid, 'deleted_at' => ago(0)]],
    ]]);

    expect($response->json("results.items.{$newUuid}.reason"))->toBe('not_found')
        ->and($response->json("results.items.{$item->uuid}.reason"))->toBe('not_found')
        ->and($response->json("results.lists.{$list->uuid}.reason"))->toBe('not_found');
    expect(Item::find($item->id))->not->toBeNull()->and(ShoppingList::find($list->id))->not->toBeNull();
});

it('cannot touch another family\'s records by guessing their uuids', function () {
    $other = makeFamily();
    $theirList = listIn($other['groceries'], ['name' => 'Theirs']);
    $theirItem = itemIn($theirList);
    $ourList = listIn($this->f['groceries']);

    $response = syncAs($this->f['admin'], ['changes' => [
        'lists' => [['uuid' => $theirList->uuid, 'name' => 'Pwned', 'deleted_at' => ago(0)]],
        'items' => [
            // their item uuid pushed against our list
            ['uuid' => $theirItem->uuid, 'list_uuid' => $ourList->uuid, 'name' => 'Pwned'],
            // their item and list
            ['uuid' => $theirItem->uuid, 'list_uuid' => $theirList->uuid, 'deleted_at' => ago(0)],
        ],
    ]])->assertOk();

    expect($response->json("results.lists.{$theirList->uuid}.status"))->toBe('rejected');
    expect(ShoppingList::find($theirList->id)->name)->toBe('Theirs');
    expect(Item::find($theirItem->id))->not->toBeNull()->and($theirItem->fresh()->name)->not->toBe('Pwned');
});

it('only hides lists from members of the same family and never from the actor', function () {
    $other = makeFamily();
    $outsider = User::factory()->create(['family_id' => $other['family']->id]);
    $sibling = User::factory()->create(['family_id' => $this->f['family']->id]);
    $uuid = (string) Str::uuid();

    syncAs($this->f['admin'], ['changes' => ['lists' => [[
        'uuid' => $uuid, 'name' => 'Gifts', 'list_type_id' => $this->f['party']->id,
        'hidden_from' => [$outsider->id, $sibling->id, $this->f['admin']->id],
    ]]]]);

    expect(ShoppingList::where('uuid', $uuid)->first()->hiddenFrom()->pluck('users.id')->all())->toBe([$sibling->id]);
});

it('exposes who a list is hidden from only to those who can manage it', function () {
    $list = listIn($this->f['party']);
    $viewer = memberWith($this->f['family'], $this->f['party'], ['can_view']);
    $hiddenUser = User::factory()->create(['family_id' => $this->f['family']->id]);
    $list->hiddenFrom()->sync([$hiddenUser->id]);

    expect(syncAs($this->f['admin'])->json('lists.0.hidden_from'))->toBe([$hiddenUser->id]);
    expect(syncAs($viewer)->json('lists.0'))->not->toHaveKey('hidden_from');
});

it('validates the payload', function () {
    $this->actingAs($this->f['admin']);

    syncAs($this->f['admin'], ['changes' => ['items' => [['uuid' => 'not-a-uuid', 'list_uuid' => 'x', 'status' => 'bogus', 'quantity' => 0]]]])
        ->assertUnprocessable()
        ->assertJsonValidationErrors(['changes.items.0.uuid', 'changes.items.0.list_uuid', 'changes.items.0.status', 'changes.items.0.quantity']);
});

it('shows web changes to the phone and phone changes to the web', function () {
    $list = listIn($this->f['groceries']);
    $item = itemIn($list);

    // a change made in the web app is stamped and reaches the phone
    $this->actingAs($this->f['admin'])->put("/shopping_list/update_item/{$item->id}", ['name' => 'Edited on web', 'quantity' => 4])->assertRedirect();

    $pulled = collect(syncAs($this->f['admin'], ['known_lists' => []])->json('items'))->firstWhere('uuid', $item->uuid);
    expect($pulled['name'])->toBe('Edited on web')->and($pulled['quantity'])->toBe(4);

    // a change from the phone shows on the web
    syncAs($this->f['admin'], ['changes' => ['items' => [[
        'uuid' => $item->uuid, 'list_uuid' => $list->uuid, 'status' => 'in_cart', 'status_changed_at' => ago(0),
    ]]]]);
    expect($item->fresh()->status_id)->toBe(2);
});

it('refuses items from a member who may only view, and from one who may not even do that', function () {
    $list = listIn($this->f['groceries']);
    $viewer = memberWith($this->f['family'], $this->f['groceries'], ['can_view']);
    $nobody = User::factory()->create(['family_id' => $this->f['family']->id]);
    $a = (string) Str::uuid();
    $b = (string) Str::uuid();

    $viewerResult = syncAs($viewer, ['changes' => ['items' => [['uuid' => $a, 'list_uuid' => $list->uuid, 'name' => 'Nope']]]]);
    expect($viewerResult->json("results.items.{$a}.reason"))->toBe('forbidden');

    $nobodyResult = syncAs($nobody, ['changes' => ['items' => [['uuid' => $b, 'list_uuid' => $list->uuid, 'name' => 'Nope']]]]);
    expect($nobodyResult->json("results.items.{$b}.reason"))->toBe('not_found');

    expect(Item::whereIn('uuid', [$a, $b])->count())->toBe(0);
});

it('refuses cart changes and renames from members without those permissions', function () {
    $list = listIn($this->f['groceries']);
    $item = itemIn($list);
    $viewer = memberWith($this->f['family'], $this->f['groceries'], ['can_view']);

    syncAs($viewer, ['changes' => ['items' => [[
        'uuid' => $item->uuid, 'list_uuid' => $list->uuid,
        'status' => 'in_cart', 'status_changed_at' => ago(0),
        'quantity' => 8, 'quantity_changed_at' => ago(0),
    ]]]]);

    expect($item->fresh()->status_id)->toBe(1)->and($item->fresh()->quantity)->not->toBe(8);

    // and renaming a list needs manage
    $result = syncAs($viewer, ['changes' => ['lists' => [['uuid' => $list->uuid, 'name' => 'Renamed', 'name_changed_at' => ago(0)]]]]);
    expect($result->json("results.lists.{$list->uuid}.status"))->toBe('rejected')
        ->and($list->fresh()->name)->not->toBe('Renamed');
});
