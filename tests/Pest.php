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
