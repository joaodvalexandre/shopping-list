<?php

use App\Enums\FamilyRole;
use App\Filament\Resources\Families\Pages\CreateFamily;
use App\Filament\Resources\Families\Pages\EditFamily;
use App\Filament\Resources\Families\Pages\ListFamilies;
use App\Filament\Resources\Families\RelationManagers\MembersRelationManager;
use App\Filament\Resources\Users\Pages\CreateUser;
use App\Filament\Resources\Users\Pages\EditUser;
use App\Filament\Resources\Users\Pages\ListUsers;
use App\Models\Family;
use App\Models\ListType;
use App\Models\ShoppingList;
use App\Models\User;
use Filament\Actions\Testing\TestAction;
use Livewire\Livewire;

beforeEach(function () {
    backofficeAdmin();
});

// --------------------------------------------------------------- families

it('creates a family with its first admin and a default list type', function () {
    Livewire::test(CreateFamily::class)
        ->fillForm(['name' => 'Silva', 'admin_name' => 'Joana Silva', 'admin_email' => 'joana@example.com'])
        ->call('create')
        ->assertHasNoFormErrors();

    $family = Family::where('name', 'Silva')->firstOrFail();
    $admin = User::where('email', 'joana@example.com')->firstOrFail();

    expect($admin->family_id)->toBe($family->id)
        ->and($admin->role)->toBe(FamilyRole::Admin)
        ->and($admin->must_change_password)->toBeTrue()
        ->and($family->listTypes()->count())->toBe(1);

    // the temporary password is shown, for that admin, in a notification that stays until dismissed
    $notification = sentNotifications()->first(fn ($n) => $n->getTitle() === __('bo_temp_password_title'));
    expect($notification)->not->toBeNull()
        ->and((string) $notification->getBody())->toContain('joana@example.com')
        ->and($notification->getDuration())->toBe('persistent');
});

it('lets the new family admin sign in with the temporary password', function () {
    Livewire::test(CreateFamily::class)
        ->fillForm(['name' => 'Silva', 'admin_name' => 'Joana', 'admin_email' => 'joana@example.com'])
        ->call('create');

    $password = shownTemporaryPassword();
    expect($password)->not->toBeNull();

    auth('admin')->logout();
    $this->post('/login', ['email' => 'joana@example.com', 'password' => $password])->assertRedirect(route('dashboard'));
});

it('validates a new family', function () {
    User::factory()->create(['email' => 'taken@example.com']);

    Livewire::test(CreateFamily::class)
        ->fillForm(['name' => '', 'admin_name' => '', 'admin_email' => 'not-an-email'])
        ->call('create')
        ->assertHasFormErrors(['name' => 'required', 'admin_name' => 'required', 'admin_email' => 'email']);

    Livewire::test(CreateFamily::class)
        ->fillForm(['name' => 'Dup', 'admin_name' => 'X', 'admin_email' => 'taken@example.com'])
        ->call('create')
        ->assertHasFormErrors(['admin_email' => 'unique']);

    expect(Family::where('name', 'Dup')->exists())->toBeFalse();
});

it('lists and renames families', function () {
    $f = makeFamily();

    Livewire::test(ListFamilies::class)->assertCanSeeTableRecords([$f['family']]);

    Livewire::test(EditFamily::class, ['record' => $f['family']->getKey()])
        ->fillForm(['name' => 'Renamed'])
        ->call('save')
        ->assertHasNoFormErrors();

    expect($f['family']->fresh()->name)->toBe('Renamed');
});

it('deletes a family with everything in it, and signs its devices out', function () {
    $f = makeFamily();
    $list = listIn($f['groceries']);
    itemIn($list);
    listIn($f['groceries'])->delete(); // a deleted list lingers as a tombstone and still points at its type
    $f['admin']->createToken('Phone', ['sync']);

    Livewire::test(ListFamilies::class)
        ->callAction(TestAction::make('delete')->table($f['family']));

    expect(Family::count())->toBe(0)->and(User::count())->toBe(0)->and(ListType::count())->toBe(0);
    expect(ShoppingList::withTrashed()->count())->toBe(0);
    expect(DB::table('personal_access_tokens')->count())->toBe(0);
});

// ---------------------------------------------------------------- members

it('adds a member to a family from the family page', function () {
    $f = makeFamily();

    Livewire::test(MembersRelationManager::class, ['ownerRecord' => $f['family'], 'pageClass' => EditFamily::class])
        ->callAction(TestAction::make('create')->table(), ['name' => 'Bia', 'email' => 'bia@example.com', 'role' => 'member'])
        ->assertHasNoFormErrors();

    $bia = User::where('email', 'bia@example.com')->firstOrFail();
    expect($bia->family_id)->toBe($f['family']->id)->and($bia->must_change_password)->toBeTrue();
});

it('creates a member in a chosen family', function () {
    $f = makeFamily();

    Livewire::test(CreateUser::class)
        ->fillForm(['family_id' => $f['family']->id, 'name' => 'Bia', 'email' => 'bia@example.com', 'role' => 'member'])
        ->call('create')
        ->assertHasNoFormErrors();

    expect(User::where('email', 'bia@example.com')->first()->family_id)->toBe($f['family']->id);
});

it('searches and filters members across families', function () {
    $a = makeFamily();
    $b = makeFamily();
    $bia = User::factory()->create(['family_id' => $a['family']->id, 'name' => 'Bia Unique']);
    $carl = User::factory()->create(['family_id' => $b['family']->id, 'name' => 'Carl Other']);

    Livewire::test(ListUsers::class)
        ->searchTable('Unique')
        ->assertCanSeeTableRecords([$bia])
        ->assertCanNotSeeTableRecords([$carl])
        ->searchTable('')
        ->filterTable('family_id', $b['family']->id)
        ->assertCanSeeTableRecords([$carl])
        ->assertCanNotSeeTableRecords([$bia]);
});

it('resets a password to a new temporary one and signs the member out everywhere', function () {
    $f = makeFamily();
    $member = User::factory()->create(['family_id' => $f['family']->id, 'password' => 'old-password-1']);
    $member->createToken('Phone', ['sync']);

    Livewire::test(ListUsers::class)
        ->callAction(TestAction::make('resetPassword')->table($member));

    $member = $member->fresh();
    expect($member->must_change_password)->toBeTrue()
        ->and(Hash::check('old-password-1', $member->password))->toBeFalse()
        ->and($member->tokens()->count())->toBe(0);
});

it('signs a member out of every device without touching their password', function () {
    $f = makeFamily();
    $member = User::factory()->create(['family_id' => $f['family']->id, 'password' => 'keep-this-1']);
    $member->createToken('Phone', ['sync']);
    $member->createToken('Tablet', ['sync']);

    Livewire::test(ListUsers::class)
        ->callAction(TestAction::make('signOutEverywhere')->table($member));

    expect($member->tokens()->count())->toBe(0)
        ->and(Hash::check('keep-this-1', $member->fresh()->password))->toBeTrue();
});

it('promotes a member to family admin', function () {
    $f = makeFamily();
    $member = memberWith($f['family'], $f['groceries'], ['can_view']);

    Livewire::test(EditUser::class, ['record' => $member->getKey()])
        ->fillForm(['role' => 'admin'])
        ->call('save')
        ->assertHasNoFormErrors();

    expect($member->fresh()->isFamilyAdmin())->toBeTrue();
});

it('never demotes or deletes the only admin of a family', function () {
    $f = makeFamily();

    Livewire::test(EditUser::class, ['record' => $f['admin']->getKey()])
        ->fillForm(['role' => 'member'])
        ->call('save');
    expect($f['admin']->fresh()->isFamilyAdmin())->toBeTrue();

    Livewire::test(ListUsers::class)
        ->callAction(TestAction::make('delete')->table($f['admin']));
    expect(User::find($f['admin']->id))->not->toBeNull();

    // with a second admin both are fine
    User::factory()->admin()->create(['family_id' => $f['family']->id]);
    Livewire::test(ListUsers::class)
        ->callAction(TestAction::make('delete')->table($f['admin']));
    expect(User::find($f['admin']->id))->toBeNull();
});

it('cannot move a member to another family by editing', function () {
    $a = makeFamily();
    $b = makeFamily();
    $member = memberWith($a['family'], $a['groceries'], ['can_view']);

    Livewire::test(EditUser::class, ['record' => $member->getKey()])
        ->fillForm(['name' => 'Renamed', 'family_id' => $b['family']->id])
        ->call('save');

    expect($member->fresh()->family_id)->toBe($a['family']->id);
});
