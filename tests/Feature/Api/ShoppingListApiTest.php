<?php

namespace Tests\Feature\Api;

use Tests\TestCase;
use App\Models\ShoppingList;
use App\Models\Item;
use App\Models\Status;
use Illuminate\Foundation\Testing\RefreshDatabase;

class ShoppingListApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Create default statuses
        Status::create(['code' => 'to_buy', 'name' => 'To Buy', 'color' => 'yellow']);
        Status::create(['code' => 'in_cart', 'name' => 'In Cart', 'color' => 'blue']);
        Status::create(['code' => 'purchased', 'name' => 'Purchased', 'color' => 'green']);
    }

    /** @test */
    public function it_can_check_health_endpoint()
    {
        $response = $this->getJson('/api/shopping-lists/health');

        $response->assertStatus(200)
                ->assertJson(['status' => 'ok']);
    }

    /** @test */
    public function it_can_fetch_all_shopping_lists()
    {
        $shoppingList = ShoppingList::create(['name' => 'Test List']);
        $status = Status::where('code', 'to_buy')->first();

        Item::create([
            'shopping_list_id' => $shoppingList->id,
            'name' => 'Test Item',
            'quantity' => '2',
            'status_id' => $status->id,
        ]);

        $response = $this->getJson('/api/shopping-lists');

        $response->assertStatus(200)
                ->assertJsonCount(1)
                ->assertJsonStructure([
                    '*' => [
                        'id',
                        'name',
                        'created_at',
                        'updated_at',
                        'items' => [
                            '*' => [
                                'id',
                                'name',
                                'quantity',
                                'status',
                                'created_at',
                                'updated_at',
                            ]
                        ]
                    ]
                ]);
    }

    /** @test */
    public function it_can_create_a_shopping_list()
    {
        $response = $this->postJson('/api/shopping-lists', [
            'name' => 'New Shopping List'
        ]);

        $response->assertStatus(201)
                ->assertJson([
                    'name' => 'New Shopping List',
                    'items' => []
                ]);

        $this->assertDatabaseHas('shopping_lists', [
            'name' => 'New Shopping List'
        ]);
    }

    /** @test */
    public function it_can_update_a_shopping_list()
    {
        $shoppingList = ShoppingList::create(['name' => 'Original Name']);

        $response = $this->putJson("/api/shopping-lists/{$shoppingList->id}", [
            'name' => 'Updated Name',
            'items' => [
                [
                    'name' => 'Item 1',
                    'quantity' => '3',
                    'status' => 'to_buy'
                ]
            ]
        ]);

        $response->assertStatus(200)
                ->assertJson([
                    'name' => 'Updated Name'
                ]);

        $this->assertDatabaseHas('shopping_lists', [
            'id' => $shoppingList->id,
            'name' => 'Updated Name'
        ]);

        $this->assertDatabaseHas('items', [
            'shopping_list_id' => $shoppingList->id,
            'name' => 'Item 1',
            'quantity' => '3'
        ]);
    }

    /** @test */
    public function it_can_delete_a_shopping_list()
    {
        $shoppingList = ShoppingList::create(['name' => 'To Delete']);

        $response = $this->deleteJson("/api/shopping-lists/{$shoppingList->id}");

        $response->assertStatus(204);

        $this->assertDatabaseMissing('shopping_lists', [
            'id' => $shoppingList->id
        ]);
    }

    /** @test */
    public function it_can_sync_shopping_lists()
    {
        $response = $this->postJson('/api/shopping-lists/sync', [
            'lists' => [
                [
                    'name' => 'Synced List 1',
                    'items' => [
                        [
                            'name' => 'Item 1',
                            'quantity' => '1',
                            'status' => 'to_buy'
                        ]
                    ]
                ],
                [
                    'name' => 'Synced List 2',
                    'items' => []
                ]
            ]
        ]);

        $response->assertStatus(200)
                ->assertJson([
                    'success' => true
                ])
                ->assertJsonStructure([
                    'success',
                    'synced_lists',
                    'conflicts'
                ]);

        $this->assertDatabaseHas('shopping_lists', [
            'name' => 'Synced List 1'
        ]);

        $this->assertDatabaseHas('shopping_lists', [
            'name' => 'Synced List 2'
        ]);
    }

    /** @test */
    public function it_validates_required_fields()
    {
        $response = $this->postJson('/api/shopping-lists', []);

        $response->assertStatus(422)
                ->assertJsonValidationErrors(['name']);
    }
}
