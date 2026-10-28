<?php

use App\Enums\ListAbility;

it('makes every ability imply view', function () {
    foreach (ListAbility::cases() as $ability) {
        $result = ListAbility::normalise([$ability->value => '1']);

        expect($result[ListAbility::View->value])->toBeTrue()
            ->and($result[$ability->value])->toBeTrue();
    }
});

it('grants nothing when nothing is requested', function () {
    expect(array_filter(ListAbility::normalise([])))->toBe([]);
});

it('ignores unknown abilities', function () {
    $result = ListAbility::normalise(['is_superuser' => '1']);

    expect($result)->not->toHaveKey('is_superuser')->and(array_filter($result))->toBe([]);
});
