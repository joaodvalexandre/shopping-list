<?php

use App\Models\Family;
use App\Models\Item;
use App\Models\ListType;
use App\Models\ShoppingList;
use App\Models\Status;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
|--------------------------------------------------------------------------
| Test Case
|--------------------------------------------------------------------------
*/

uses(TestCase::class, RefreshDatabase::class)->in('Feature');

/*
|--------------------------------------------------------------------------
| Helpers
|--------------------------------------------------------------------------
*/

/**
 * The three item statuses the app hard-codes by id (1 to buy, 2 in cart, 3 purchased).
 */
function seedStatuses(): void
{
    if (Status::count() === 0) {
        Status::create(['code' => 'to_buy', 'color' => '#FFA500']);
        Status::create(['code' => 'in_cart', 'color' => '#1E90FF']);
        Status::create(['code' => 'purchased', 'color' => '#4CAF50']);
    }
}

/**
 * A family with an admin, a "Groceries" type and a "Party" type.
 *
 * @return array{family: Family, admin: User, groceries: ListType, party: ListType}
 */
function makeFamily(): array
{
    seedStatuses();

    $family = Family::factory()->create();
    $admin = User::factory()->admin()->create(['family_id' => $family->id]);

    return [
        'family' => $family,
        'admin' => $admin,
        'groceries' => ListType::factory()->create(['family_id' => $family->id, 'name' => 'Groceries']),
        'party' => ListType::factory()->create(['family_id' => $family->id, 'name' => 'Party']),
    ];
}

/**
 * A plain member of $family holding exactly the given abilities on $type.
 *
 * @param  list<string>  $abilities  ListAbility column names
 */
function memberWith(Family $family, ListType $type, array $abilities): User
{
    $member = User::factory()->create(['family_id' => $family->id]);
    $member->syncListPermissions([$type->id => array_fill_keys($abilities, true)]);

    return $member;
}

function listIn(ListType $type, array $attributes = []): ShoppingList
{
    return ShoppingList::factory()->create(['list_type_id' => $type->id, 'family_id' => $type->family_id] + $attributes);
}

function itemIn(ShoppingList $list, int $statusId = 1): Item
{
    return Item::factory()->create(['shopping_list_id' => $list->id, 'status_id' => $statusId]);
}

/**
 * Sign in to the backoffice as a new administrator (the `admin` guard).
 * A super administrator unless told otherwise; pass a shipped role name
 * (e.g. "content-editor"), or null for an administrator with no role at all.
 */
function backofficeAdmin(array $attributes = [], ?string $role = App\Models\Role::SUPER_ADMIN): App\Models\Admin
{
    $factory = App\Models\Admin::factory();
    $admin = ($role === null ? $factory : $factory->withRole($role))->create($attributes);
    test()->actingAs($admin, 'admin');

    // actingAs() also makes `admin` the default guard; in a real request the default
    // stays `web`, and the backoffice names its own guard. Keep tests faithful to that.
    Illuminate\Support\Facades\Auth::shouldUse('web');

    Filament\Facades\Filament::setCurrentPanel('admin');

    return $admin;
}

/**
 * The Filament notifications sent so far in this test (what assertNotified() inspects).
 *
 * @return Illuminate\Support\Collection<int, Filament\Notifications\Notification>
 */
function sentNotifications(): Illuminate\Support\Collection
{
    app(Filament\Notifications\NotificationMailbox::class)->flush();

    $component = new Filament\Notifications\Livewire\Notifications;
    $component->mount();
    $component->pullNotificationsFromSession();

    return $component->notifications;
}

/** The temporary password shown to the admin in the latest "temporary password" notification. */
function shownTemporaryPassword(): ?string
{
    $notification = sentNotifications()->first(
        fn (Filament\Notifications\Notification $n) => $n->getTitle() === __('bo_temp_password_title')
    );

    preg_match('/<code[^>]*>(.*?)<\/code>/', (string) $notification?->getBody(), $matches);

    return isset($matches[1]) ? html_entity_decode($matches[1], ENT_QUOTES) : null;
}
