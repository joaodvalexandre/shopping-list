<?php

namespace App\Enums;

/**
 * What a member may do with the lists of one list type.
 * The value is the column on the list_type_user pivot.
 */
enum ListAbility: string
{
    case View = 'can_view';
    case AddItems = 'can_add_items';
    case EditItems = 'can_edit_items';
    case ChangeStatus = 'can_change_status';
    case ManageLists = 'can_manage_lists';

    public function label(): string
    {
        return __('ability_' . $this->value);
    }

    /**
     * Normalise a set of requested abilities: every ability implies "view",
     * so nobody ends up able to act on lists they cannot see.
     *
     * @param  array<string, mixed>  $requested  ability column => truthy/falsy
     * @return array<string, bool>
     */
    public static function normalise(array $requested): array
    {
        $result = [];
        foreach (self::cases() as $ability) {
            $result[$ability->value] = (bool) ($requested[$ability->value] ?? false);
        }

        if (in_array(true, $result, true)) {
            $result[self::View->value] = true;
        }

        return $result;
    }
}
