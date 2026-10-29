<?php

namespace Database\Seeders;

use App\Enums\FamilyRole;
use App\Models\ListType;
use App\Models\ShoppingList;
use App\Models\User;
use App\Services\FamilyProvisioner;
use App\Support\TemporaryPassword;
use Illuminate\Database\Seeder;
use RuntimeException;

/**
 * A ready-made family to try the web app and the phone app with. Never in
 * production, and not part of DatabaseSeeder: run it on purpose with
 *   php artisan db:seed --class=DemoSeeder
 *
 * Everyone's first-time password is the family name ("Silva"), as for real accounts.
 *
 *   joana@demo.test  family admin: everything
 *   bia@demo.test    member: adds items and uses the cart in Groceries, only looks at Pharmacy;
 *                    cannot see the "Bia's birthday" list at all
 *   rui@demo.test    member: edits items and manages lists in Groceries; nothing else
 */
class DemoSeeder extends Seeder
{
    public function run(): void
    {
        if (app()->isProduction()) {
            throw new RuntimeException('The demo family is not for production.');
        }

        if (User::where('email', 'joana@demo.test')->exists()) {
            $this->command?->warn('The demo family already exists.');

            return;
        }

        $this->call(StatusSeeder::class);

        $result = app(FamilyProvisioner::class)->create('Silva', 'Joana Silva', 'joana@demo.test');
        $family = $result['family'];
        $joana = $result['admin'];

        $groceries = $family->listTypes()->first();   // "Groceries" (the family's default type)
        $pharmacy = ListType::create(['family_id' => $family->id, 'name' => 'Pharmacy']);
        $party = ListType::create(['family_id' => $family->id, 'name' => 'Party']);

        $bia = $this->member($family, 'Bia Silva', 'bia@demo.test');
        $bia->syncListPermissions([
            $groceries->id => ['can_add_items' => true, 'can_change_status' => true],
            $pharmacy->id => ['can_view' => true],
            $party->id => ['can_view' => true],
        ]);

        $rui = $this->member($family, 'Rui Silva', 'rui@demo.test');
        $rui->syncListPermissions([
            $groceries->id => ['can_edit_items' => true, 'can_manage_lists' => true],
        ]);

        $this->list($family, $joana, $groceries, 'Weekly shop', [
            ['Milk', 2, 1], ['Bread', 1, 1], ['Apples', 6, 2], ['Rice', 1, 2], ['Coffee', 1, 3], ['Eggs', 12, 3],
        ]);
        $this->list($family, $joana, $groceries, 'Barbecue on Sunday', [
            ['Sausages', 8, 1], ['Charcoal', 1, 1], ['Beer', 12, 1],
        ]);
        $this->list($family, $joana, $pharmacy, 'Pharmacy', [
            ['Paracetamol', 1, 1], ['Plasters', 2, 1],
        ]);
        $this->list($family, $joana, $groceries, 'Empty list', []);

        // The surprise: Bia must never see this one
        $birthday = $this->list($family, $joana, $party, "Bia's birthday", [
            ['Cake', 1, 1], ['Candles', 20, 1], ['Balloons', 30, 2],
        ]);
        $birthday->hiddenFrom()->sync([$bia->id]);
    }

    private function member($family, string $name, string $email): User
    {
        return User::create([
            'family_id' => $family->id,
            'name' => $name,
            'email' => $email,
            'role' => FamilyRole::Member,
            'password' => TemporaryPassword::for($family),
            'must_change_password' => true,
        ]);
    }

    /** @param  list<array{0: string, 1: int, 2: int}>  $items  name, quantity, status id */
    private function list($family, User $creator, ListType $type, string $name, array $items): ShoppingList
    {
        $list = ShoppingList::create([
            'name' => $name,
            'list_type_id' => $type->id,
            'family_id' => $family->id,
            'created_by' => $creator->id,
        ]);

        foreach ($items as [$itemName, $quantity, $status]) {
            $list->items()->create(['name' => $itemName, 'quantity' => $quantity, 'status_id' => $status]);
        }

        return $list;
    }
}
