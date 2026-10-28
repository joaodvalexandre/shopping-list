<?php

use App\Models\ShoppingList;
use App\Models\User;

beforeEach(function () {
    $this->f = makeFamily();
});

it('shows a member only the lists of types they may view', function () {
    $groceries = listIn($this->f['groceries'], ['name' => 'Weekly shop']);
    $party = listIn($this->f['party'], ['name' => 'Birthday party']);
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view']);

    $this->actingAs($member)->get('/shopping_list')
        ->assertOk()
        ->assertSee('Weekly shop')
        ->assertDontSee('Birthday party');

    $this->actingAs($member)->get("/shopping_list/{$party->id}")->assertNotFound();
    $this->actingAs($member)->get("/shopping_list/{$groceries->id}")->assertOk();
});

it('lets a family admin see every list of their family', function () {
    $groceries = listIn($this->f['groceries']);
    $party = listIn($this->f['party']);

    $this->actingAs($this->f['admin'])->get("/shopping_list/{$groceries->id}")->assertOk();
    $this->actingAs($this->f['admin'])->get("/shopping_list/{$party->id}")->assertOk();
});

it('never exposes another family\'s data, even to its admin', function () {
    $other = makeFamily();
    $theirList = listIn($other['groceries'], ['name' => 'Secret of the others']);
    $theirItem = itemIn($theirList);

    $admin = $this->f['admin'];

    $this->actingAs($admin)->get('/shopping_list')->assertDontSee('Secret of the others');
    $this->actingAs($admin)->get('/dashboard')->assertDontSee('Secret of the others');
    $this->actingAs($admin)->get("/shopping_list/{$theirList->id}")->assertNotFound();
    $this->actingAs($admin)->get("/shopping_list/{$theirList->id}/edit")->assertNotFound();
    $this->actingAs($admin)->get("/shopping_list/export/{$theirList->id}")->assertNotFound();
    $this->actingAs($admin)->get("/shopping_list/edit_item/{$theirItem->id}")->assertNotFound();
    $this->actingAs($admin)->delete("/shopping_list/{$theirList->id}")->assertNotFound();
    $this->actingAs($admin)->delete("/shopping_list/destroy_item/{$theirItem->id}")->assertNotFound();
    $this->actingAs($admin)->post("/shopping_list/add_cart/{$theirItem->id}")->assertNotFound();
    $this->actingAs($admin)->post("/shopping_list/mark_purchased/{$theirList->id}")->assertNotFound();
    $this->actingAs($admin)->post("/shopping_list/{$theirList->id}/store_item", ['name' => 'x', 'quantity' => 1])->assertNotFound();

    expect(ShoppingList::find($theirList->id))->not->toBeNull();
    expect($theirItem->fresh()->status_id)->toBe(1);
});

it('hides a list from chosen members, admins included', function () {
    $list = listIn($this->f['party'], ['name' => 'Surprise party']);
    $birthday = memberWith($this->f['family'], $this->f['party'], ['can_view', 'can_add_items']);
    $otherAdmin = User::factory()->admin()->create(['family_id' => $this->f['family']->id]);
    $helper = memberWith($this->f['family'], $this->f['party'], ['can_view']);

    $list->hiddenFrom()->sync([$birthday->id, $otherAdmin->id]);

    foreach ([$birthday, $otherAdmin] as $hiddenUser) {
        $this->actingAs($hiddenUser)->get('/shopping_list')->assertDontSee('Surprise party');
        $this->actingAs($hiddenUser)->get('/dashboard')->assertDontSee('Surprise party');
        $this->actingAs($hiddenUser)->get("/shopping_list/{$list->id}")->assertNotFound();
        $this->actingAs($hiddenUser)->post("/shopping_list/{$list->id}/store_item", ['name' => 'gift', 'quantity' => 1])->assertNotFound();
    }

    $this->actingAs($helper)->get("/shopping_list/{$list->id}")->assertOk()->assertSee('Surprise party');
    $this->actingAs($this->f['admin'])->get("/shopping_list/{$list->id}")->assertOk();
});

it('keeps hidden lists out of item queries too', function () {
    $list = listIn($this->f['party']);
    $item = itemIn($list);
    $birthday = memberWith($this->f['family'], $this->f['party'], ['can_view', 'can_edit_items', 'can_change_status']);
    $list->hiddenFrom()->sync([$birthday->id]);

    $this->actingAs($birthday)->get("/shopping_list/edit_item/{$item->id}")->assertNotFound();
    $this->actingAs($birthday)->post("/shopping_list/add_cart/{$item->id}")->assertNotFound();
    $this->actingAs($birthday)->delete("/shopping_list/destroy_item/{$item->id}")->assertNotFound();
    expect($item->fresh())->not->toBeNull()->and($item->fresh()->status_id)->toBe(1);
});

it('gives members with no permission at all an empty list page', function () {
    listIn($this->f['groceries'], ['name' => 'Weekly shop']);
    $nobody = User::factory()->create(['family_id' => $this->f['family']->id]);

    $this->actingAs($nobody)->get('/shopping_list')->assertOk()->assertDontSee('Weekly shop');
    $this->actingAs($nobody)->get('/shopping_list/create')->assertForbidden();
});

it('renders the dashboard cards for visible lists only', function () {
    $visible = listIn($this->f['groceries'], ['name' => 'Weekly shop']);
    itemIn($visible);
    listIn($this->f['party'], ['name' => 'Birthday party']);
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view']);

    $this->actingAs($member)->get('/dashboard')
        ->assertOk()
        ->assertSee('Weekly shop')
        ->assertDontSee('Birthday party');
});
