<?php

namespace App\Policies;

use App\Enums\ListAbility;
use App\Models\ListType;
use App\Models\ShoppingList;
use App\Models\User;

/**
 * Every check requires the list to be in the user's family and not hidden
 * from them; hiding wins over every role. Controllers fetch lists with
 * ShoppingList::visibleTo(), so inaccessible lists answer 404 rather than
 * revealing that they exist - this policy is the second line of defence.
 */
class ShoppingListPolicy
{
    public function view(User $user, ShoppingList $list): bool
    {
        return $this->allows($user, $list, ListAbility::View);
    }

    /**
     * Creating a list needs "manage lists" on the chosen list type.
     */
    public function create(User $user, ListType $type): bool
    {
        return (int) $type->family_id === (int) $user->family_id
            && $user->canOnListType(ListAbility::ManageLists, $type);
    }

    public function update(User $user, ShoppingList $list): bool
    {
        return $this->allows($user, $list, ListAbility::ManageLists);
    }

    public function delete(User $user, ShoppingList $list): bool
    {
        return $this->allows($user, $list, ListAbility::ManageLists);
    }

    public function addItems(User $user, ShoppingList $list): bool
    {
        return $this->allows($user, $list, ListAbility::AddItems);
    }

    public function editItems(User $user, ShoppingList $list): bool
    {
        return $this->allows($user, $list, ListAbility::EditItems);
    }

    public function changeStatus(User $user, ShoppingList $list): bool
    {
        return $this->allows($user, $list, ListAbility::ChangeStatus);
    }

    private function allows(User $user, ShoppingList $list, ListAbility $ability): bool
    {
        return (int) $list->family_id === (int) $user->family_id
            && ! $list->isHiddenFrom($user)
            && $user->canOnListType($ability, $list->list_type_id);
    }
}
