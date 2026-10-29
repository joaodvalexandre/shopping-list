<?php

use App\Models\Item;

beforeEach(function () {
    $this->f = makeFamily();
    $this->bia = memberWith($this->f['family'], $this->f['groceries'], ['can_view', 'can_add_items', 'can_change_status']);
    $this->list = listIn($this->f['groceries'], ['name' => 'Weekly shop']);
});

it('says where the shopping stands across the lists, not just one card per list', function () {
    Item::factory()->create(['shopping_list_id' => $this->list->id, 'name' => 'Milk', 'quantity' => 2, 'status_id' => 1]);
    Item::factory()->create(['shopping_list_id' => $this->list->id, 'name' => 'Bread', 'status_id' => 2]);
    Item::factory()->create(['shopping_list_id' => $this->list->id, 'name' => 'Rice', 'status_id' => 3]);

    $this->actingAs($this->bia)->get('/dashboard')
        ->assertOk()
        ->assertSee('data-dashboard="totals"', false)
        ->assertSee('data-dashboard="in-cart"', false)
        ->assertSee('data-dashboard="to-buy"', false)
        ->assertSee('data-dashboard="progress"', false)
        ->assertSeeInOrder(['data-dashboard="in-cart"', 'Bread', 'data-dashboard="to-buy"', 'Milk']);
});

it('shows what is in the cart and what is still to buy, with the list each is in', function () {
    $other = listIn($this->f['groceries'], ['name' => 'Barbecue']);
    Item::factory()->create(['shopping_list_id' => $other->id, 'name' => 'Sausages', 'status_id' => 1]);
    Item::factory()->create(['shopping_list_id' => $this->list->id, 'name' => 'Eggs', 'status_id' => 2]);

    $html = $this->actingAs($this->bia)->get('/dashboard')->assertOk()->getContent();

    expect($html)->toContain('Sausages')->toContain('Barbecue')->toContain('Eggs')->toContain('Weekly shop');
});

it('only counts what the person may see', function () {
    $hidden = listIn($this->f['groceries'], ['name' => 'Surprise party']);
    $hidden->hiddenFrom()->sync([$this->bia->id]);
    Item::factory()->create(['shopping_list_id' => $hidden->id, 'name' => 'Cake', 'status_id' => 1]);

    $this->actingAs($this->bia)->get('/dashboard')->assertOk()->assertDontSee('Cake')->assertDontSee('Surprise party');
});

it('says what to do when there are no lists', function () {
    $family = makeFamily();
    $member = memberWith($family['family'], $family['groceries'], ['can_view']);

    $this->actingAs($member)->get('/dashboard')->assertOk()->assertSee(__('dashboard_information'));
});
