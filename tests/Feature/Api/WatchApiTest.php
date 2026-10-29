<?php

use Laravel\Sanctum\Sanctum;

beforeEach(function () {
    $this->f = makeFamily();
    $this->bia = memberWith($this->f['family'], $this->f['groceries'], ['can_view', 'can_add_items', 'can_change_status']);
});

/** The marker the phone is given, asked as $user. */
function marker($test, $user): string
{
    app('auth')->forgetGuards();
    Sanctum::actingAs($user, ['sync']);

    return $test->getJson('/api/v1/watch')->assertOk()->json('version');
}

it('needs a signed-in phone', function () {
    $this->getJson('/api/v1/watch')->assertUnauthorized();
});

it('gives the same marker until something changes', function () {
    itemIn(listIn($this->f['groceries']));

    expect(marker($this, $this->bia))->toBe(marker($this, $this->bia));
});

it('moves the marker when an item is changed, added or deleted, and when a list is added', function () {
    $list = listIn($this->f['groceries']);
    $item = itemIn($list);
    $seen = marker($this, $this->bia);

    $this->travel(2)->seconds();
    $item->update(['name' => 'Oat milk']);
    $afterEdit = marker($this, $this->bia);
    expect($afterEdit)->not->toBe($seen);

    $this->travel(2)->seconds();
    itemIn($list);
    $afterAdd = marker($this, $this->bia);
    expect($afterAdd)->not->toBe($afterEdit);

    $this->travel(2)->seconds();
    $item->delete();
    $afterDelete = marker($this, $this->bia);
    expect($afterDelete)->not->toBe($afterAdd);

    $this->travel(2)->seconds();
    listIn($this->f['groceries']);
    expect(marker($this, $this->bia))->not->toBe($afterDelete);
});

it('does not move for what this person may not see', function () {
    itemIn(listIn($this->f['groceries']));

    // a list hidden from Bia
    $hidden = listIn($this->f['groceries']);
    $hidden->hiddenFrom()->sync([$this->bia->id]);
    $seen = marker($this, $this->bia);

    $this->travel(2)->seconds();
    itemIn($hidden);                              // an item in the hidden list
    itemIn(listIn($this->f['party']));            // and a list of a type she has no right to

    expect(marker($this, $this->bia))->toBe($seen);
});

it('moves when what this person may see changes', function () {
    itemIn(listIn($this->f['party']));
    $seen = marker($this, $this->bia);            // the Party type is not hers yet

    $this->travel(2)->seconds();
    $this->bia->syncListPermissions([
        $this->f['groceries']->id => ['can_view' => true],
        $this->f['party']->id => ['can_view' => true],
    ]);

    expect(marker($this, $this->bia))->not->toBe($seen);
});

it('never mixes up families', function () {
    $other = makeFamily();
    $seen = marker($this, $this->bia);

    $this->travel(2)->seconds();
    itemIn(listIn($other['groceries']));

    expect(marker($this, $this->bia))->toBe($seen);
});

it('can be asked every few seconds without running into the general limit', function () {
    Sanctum::actingAs($this->bia, ['sync']);

    foreach (range(1, 70) as $i) {
        $this->getJson('/api/v1/watch')->assertOk();
    }
});
