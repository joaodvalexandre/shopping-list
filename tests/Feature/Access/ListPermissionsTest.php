<?php

use App\Models\Item;
use App\Models\ShoppingList;
use App\Models\User;

beforeEach(function () {
    $this->f = makeFamily();
    $this->list = listIn($this->f['groceries']);
    $this->item = itemIn($this->list);
});

it('lets a member who can only add items add, and nothing else', function () {
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view', 'can_add_items']);
    $this->actingAs($member);

    $this->post("/shopping_list/{$this->list->id}/store_item", ['name' => 'Milk', 'quantity' => 2])
        ->assertRedirect();
    expect(Item::where('name', 'Milk')->where('shopping_list_id', $this->list->id)->exists())->toBeTrue();

    // cannot edit/delete items
    $this->get("/shopping_list/edit_item/{$this->item->id}")->assertForbidden();
    $this->put("/shopping_list/update_item/{$this->item->id}", ['name' => 'Changed', 'quantity' => 1])->assertForbidden();
    $this->delete("/shopping_list/destroy_item/{$this->item->id}")->assertForbidden();
    // cannot move through the cart
    $this->post("/shopping_list/add_cart/{$this->item->id}")->assertForbidden();
    $this->post("/shopping_list/mark_purchased/{$this->list->id}")->assertForbidden();
    // cannot manage lists
    $this->get("/shopping_list/{$this->list->id}/edit")->assertForbidden();
    $this->put("/shopping_list/{$this->list->id}", ['name' => 'Renamed', 'list_type_id' => $this->f['groceries']->id])->assertForbidden();
    $this->delete("/shopping_list/{$this->list->id}")->assertForbidden();
    $this->get('/shopping_list/create')->assertForbidden();

    expect($this->item->fresh()->name)->not->toBe('Changed')->and($this->item->fresh()->status_id)->toBe(1);
    expect(ShoppingList::find($this->list->id))->not->toBeNull();
});

it('lets a member who can only change status move items through the cart', function () {
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view', 'can_change_status']);
    $this->actingAs($member);

    $this->post("/shopping_list/add_cart/{$this->item->id}")->assertRedirect();
    expect($this->item->fresh()->status_id)->toBe(2);

    $this->post("/shopping_list/mark_purchased/{$this->list->id}")->assertRedirect();
    expect($this->item->fresh()->status_id)->toBe(3);

    $this->post("/shopping_list/{$this->list->id}/store_item", ['name' => 'Milk', 'quantity' => 1])->assertForbidden();
});

it('lets a member who can edit items edit and delete them', function () {
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view', 'can_edit_items']);
    $this->actingAs($member);

    $this->put("/shopping_list/update_item/{$this->item->id}", ['name' => 'Bread', 'quantity' => 3])->assertRedirect();
    expect($this->item->fresh()->name)->toBe('Bread');

    $this->delete("/shopping_list/destroy_item/{$this->item->id}")->assertRedirect();
    expect(Item::find($this->item->id))->toBeNull();
});

it('does not delete an item that is in the cart, and does not offer to', function () {
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view', 'can_edit_items', 'can_change_status']);
    $this->actingAs($member);

    $this->post("/shopping_list/add_cart/{$this->item->id}")->assertRedirect();
    expect($this->item->fresh()->isInCart())->toBeTrue();

    $this->get("/shopping_list/{$this->list->id}")->assertOk()
        ->assertDontSee(route('shopping_list.destroy_item', ['item_id' => $this->item->id]), false);

    $this->delete("/shopping_list/destroy_item/{$this->item->id}")->assertRedirect()
        ->assertSessionHas('notification.type', 'error');
    expect(Item::find($this->item->id))->not->toBeNull();

    // taken out of the cart again, it can go
    $this->post("/shopping_list/remove_cart/{$this->item->id}")->assertRedirect();
    $this->delete("/shopping_list/destroy_item/{$this->item->id}")->assertRedirect();
    expect(Item::find($this->item->id))->toBeNull();
});

it('lets a selected member manage lists of a type without being an admin', function () {
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_manage_lists']);
    $this->actingAs($member);

    // manage implies view
    $this->get("/shopping_list/{$this->list->id}")->assertOk();

    $this->post('/shopping_list', ['name' => 'New one', 'list_type_id' => $this->f['groceries']->id])->assertRedirect(route('shopping_list.index'));
    $created = ShoppingList::where('name', 'New one')->firstOrFail();
    expect($created->family_id)->toBe($this->f['family']->id)->and($created->created_by)->toBe($member->id);

    $this->put("/shopping_list/{$created->id}", ['name' => 'Renamed', 'list_type_id' => $this->f['groceries']->id])->assertRedirect();
    expect($created->fresh()->name)->toBe('Renamed');

    $this->delete("/shopping_list/{$created->id}")->assertRedirect();
    expect(ShoppingList::find($created->id))->toBeNull();
});

it('does not let a manager create lists in a type they do not manage', function () {
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_manage_lists']);

    $this->actingAs($member)
        ->post('/shopping_list', ['name' => 'Sneaky', 'list_type_id' => $this->f['party']->id])
        ->assertSessionHasErrors('list_type_id');

    expect(ShoppingList::where('name', 'Sneaky')->exists())->toBeFalse();
});

it('does not let a manager move a list into a type they do not manage', function () {
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_manage_lists']);

    $this->actingAs($member)
        ->put("/shopping_list/{$this->list->id}", ['name' => 'Moved', 'list_type_id' => $this->f['party']->id])
        ->assertSessionHasErrors('list_type_id');

    expect($this->list->fresh()->list_type_id)->toBe($this->f['groceries']->id);
});

it('does not accept a list type from another family', function () {
    $other = makeFamily();

    $this->actingAs($this->f['admin'])
        ->post('/shopping_list', ['name' => 'Cross', 'list_type_id' => $other['groceries']->id])
        ->assertSessionHasErrors('list_type_id');

    expect(ShoppingList::where('name', 'Cross')->exists())->toBeFalse();
});

it('only hides lists from members of the same family and never from the creator', function () {
    $other = makeFamily();
    $outsider = User::factory()->create(['family_id' => $other['family']->id]);
    $sibling = User::factory()->create(['family_id' => $this->f['family']->id]);

    $this->actingAs($this->f['admin'])->post('/shopping_list', [
        'name' => 'Gift list',
        'list_type_id' => $this->f['party']->id,
        'hidden_from' => [$outsider->id, $sibling->id, $this->f['admin']->id],
    ])->assertRedirect();

    $list = ShoppingList::where('name', 'Gift list')->firstOrFail();

    expect($list->hiddenFrom()->pluck('users.id')->all())->toBe([$sibling->id]);
});

it('treats admins as holding every permission in their own family only', function () {
    $other = makeFamily();
    $theirs = listIn($other['groceries']);

    $this->actingAs($this->f['admin'])
        ->post("/shopping_list/{$this->list->id}/store_item", ['name' => 'Eggs', 'quantity' => 1])
        ->assertRedirect();
    expect(Item::where('name', 'Eggs')->exists())->toBeTrue();

    expect($this->f['admin']->can('view', $theirs))->toBeFalse();
    expect($this->f['admin']->can('delete', $theirs))->toBeFalse();
});

it('validates item input', function () {
    $this->actingAs($this->f['admin'])
        ->post("/shopping_list/{$this->list->id}/store_item", ['name' => '', 'quantity' => 0])
        ->assertSessionHasErrors(['name', 'quantity']);
});

it('rejects state changes made with GET', function () {
    $this->actingAs($this->f['admin'])->get("/shopping_list/add_cart/{$this->item->id}")->assertStatus(405);
    $this->actingAs($this->f['admin'])->get("/shopping_list/mark_purchased/{$this->list->id}")->assertStatus(405);
    expect($this->item->fresh()->status_id)->toBe(1);
});
