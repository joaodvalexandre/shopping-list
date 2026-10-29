<?php

use App\Models\Activity;
use App\Models\Item;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

beforeEach(function () {
    $this->f = makeFamily();
    $this->bia = memberWith($this->f['family'], $this->f['groceries'], ['can_view', 'can_add_items', 'can_change_status']);
});

/** Do something as $user, the way a request would. */
function asUser(User $user, Closure $work): void
{
    request()->setUserResolver(fn () => $user);
    $work();
    request()->setUserResolver(fn () => null);
}

it('records what happens on a list, and who did it', function () {
    $list = listIn($this->f['groceries']);

    asUser($this->bia, function () use ($list) {
        $item = $list->items()->create(['name' => 'Milk', 'quantity' => 2, 'status_id' => 1]);
        $item->update(['status_id' => 2]);
        $item->update(['status_id' => 3]);
        $item->update(['name' => 'Oat milk', 'quantity' => 3]);   // not news
    });

    $kinds = Activity::orderBy('id')->get()->map(fn (Activity $a) => [$a->kind, $a->subject, $a->actor_id])->all();

    expect($kinds)->toContain(['item_added', 'Milk', $this->bia->id])
        ->and($kinds)->toContain(['item_in_cart', 'Milk', $this->bia->id])
        ->and($kinds)->toContain(['item_purchased', 'Milk', $this->bia->id])
        ->and(collect($kinds)->where(0, 'item_added'))->toHaveCount(1)
        ->and(Activity::count())->toBe(count($kinds));   // the rename and quantity change left nothing behind
});

it('records a created list', function () {
    asUser($this->bia, fn () => listIn($this->f['groceries'], ['name' => 'Barbecue']));

    $activity = Activity::where('kind', 'list_created')->firstOrFail();
    expect($activity->family_id)->toBe($this->f['family']->id)->and($activity->actor_id)->toBe($this->bia->id);
});

it('starts a new reader from where the feed stands, without announcing the past', function () {
    $list = listIn($this->f['groceries']);
    asUser($this->bia, fn () => $list->items()->create(['name' => 'Milk', 'quantity' => 1, 'status_id' => 1]));

    Sanctum::actingAs($this->f['admin'], ['sync']);
    $response = $this->getJson('/api/v1/activity')->assertOk();

    expect($response->json('data'))->toBe([])
        ->and($response->json('last_id'))->toBe((int) Activity::max('id'));
});

it('tells what others did since the last id, never the reader own doing', function () {
    $list = listIn($this->f['groceries'], ['name' => 'Barbecue']);
    $cursor = (int) Activity::max('id');

    asUser($this->bia, fn () => $list->items()->create(['name' => 'Sausages', 'quantity' => 4, 'status_id' => 1]));
    asUser($this->f['admin'], fn () => $list->items()->create(['name' => 'Bread', 'quantity' => 1, 'status_id' => 1]));

    Sanctum::actingAs($this->f['admin'], ['sync']);
    $response = $this->getJson("/api/v1/activity?after={$cursor}")->assertOk();

    expect($response->json('data'))->toHaveCount(1)
        ->and($response->json('data.0.kind'))->toBe('item_added')
        ->and($response->json('data.0.actor'))->toBe($this->bia->name)
        ->and($response->json('data.0.item'))->toBe('Sausages')
        ->and($response->json('data.0.quantity'))->toBe(4)
        ->and($response->json('data.0.list'))->toBe('Barbecue')
        ->and($response->json('data.0.list_uuid'))->toBe($list->uuid)
        ->and($response->json('last_id'))->toBe((int) Activity::max('id'));

    // nothing new: an empty answer that keeps the cursor
    $last = $response->json('last_id');
    $this->getJson("/api/v1/activity?after={$last}")->assertOk()->assertJsonPath('data', [])->assertJsonPath('last_id', $last);
});

it('only tells about the lists the reader may see', function () {
    $visible = listIn($this->f['groceries'], ['name' => 'Groceries list']);
    $otherType = listIn($this->f['party'], ['name' => 'Party list']);                 // Bia cannot view this type
    $hidden = listIn($this->f['groceries'], ['name' => 'Surprise']);
    $hidden->hiddenFrom()->sync([$this->bia->id]);
    $cursor = (int) Activity::max('id');

    foreach ([$visible, $otherType, $hidden] as $list) {
        asUser($this->f['admin'], fn () => $list->items()->create(['name' => 'Thing', 'quantity' => 1, 'status_id' => 1]));
    }

    Sanctum::actingAs($this->bia, ['sync']);
    $lists = collect($this->getJson("/api/v1/activity?after={$cursor}")->assertOk()->json('data'))->pluck('list')->all();

    expect($lists)->toBe(['Groceries list']);
});

it('never shows another family what happened', function () {
    $list = listIn($this->f['groceries']);
    $cursor = (int) Activity::max('id');
    asUser($this->bia, fn () => $list->items()->create(['name' => 'Milk', 'quantity' => 1, 'status_id' => 1]));

    $other = makeFamily();
    Sanctum::actingAs($other['admin'], ['sync']);

    $this->getJson("/api/v1/activity?after={$cursor}")->assertOk()->assertJsonPath('data', []);
});

it('needs a signed-in phone', function () {
    $this->getJson('/api/v1/activity')->assertUnauthorized();
});

it('records the change when it comes through the phone sync', function () {
    $list = listIn($this->f['groceries'], ['name' => 'Barbecue']);
    $cursor = (int) Activity::max('id');
    $uuid = (string) Illuminate\Support\Str::uuid();

    Sanctum::actingAs($this->bia, ['sync']);
    $this->postJson('/api/v1/sync', [
        'since' => null,
        'known_lists' => [],
        'changes' => ['items' => [[
            'uuid' => $uuid, 'list_uuid' => $list->uuid, 'name' => 'Ribs', 'quantity' => 2, 'status' => 'to_buy',
            'name_changed_at' => now()->toIso8601String(), 'quantity_changed_at' => now()->toIso8601String(), 'status_changed_at' => now()->toIso8601String(),
        ]]],
    ])->assertOk();

    Sanctum::actingAs($this->f['admin'], ['sync']);
    expect(collect($this->getJson("/api/v1/activity?after={$cursor}")->json('data'))->pluck('item')->all())->toBe(['Ribs']);
    expect(Item::where('uuid', $uuid)->exists())->toBeTrue();
});
