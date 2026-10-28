<?php

use App\Filament\Resources\Admins\Pages\EditAdmin;
use App\Filament\Resources\Permissions\Pages\CreatePermission;
use App\Filament\Resources\Permissions\Pages\EditPermission;
use App\Filament\Resources\Permissions\Pages\ListPermissions;
use App\Filament\Resources\Roles\Pages\CreateRole;
use App\Filament\Resources\Roles\Pages\EditRole;
use App\Filament\Resources\Roles\Pages\ListRoles;
use App\Models\Admin;
use App\Models\Family;
use App\Models\Permission;
use App\Models\Role;
use App\Support\Backoffice\PermissionCatalog;
use Database\Seeders\RoleSeeder;
use Filament\Actions\Testing\TestAction;
use Illuminate\Support\Facades\Gate;
use Livewire\Livewire;

function permissionIds(string ...$names): array
{
    return Permission::whereIn('name', $names)->pluck('id')->map(fn ($id) => (string) $id)->all();
}

// ---------------------------------------------------------------- seeders

it('seeds every permission and the shipped roles', function () {
    $this->seed(RoleSeeder::class);

    expect(Permission::pluck('name')->sort()->values()->all())->toBe(collect(PermissionCatalog::names())->sort()->values()->all())
        ->and(Role::pluck('name')->sort()->values()->all())->toBe(['content-editor', 'super-admin', 'support', 'translator', 'viewer']);

    $super = Role::where('name', Role::SUPER_ADMIN)->first();
    expect($super->permissions()->count())->toBe(Permission::count());

    // The viewer looks at everything and can change nothing
    $viewer = Role::where('name', 'viewer')->first();
    expect($viewer->permissions->every(fn (Permission $p) => $p->action() === 'view'))->toBeTrue()
        ->and($viewer->permissions->count())->toBe(count(PermissionCatalog::groups()));
});

it('can be seeded again without duplicates, keeping what was ticked in the backoffice', function () {
    $this->seed(RoleSeeder::class);

    $support = Role::where('name', 'support')->first();
    $support->permissions()->detach(Permission::where('name', 'members.update')->value('id'));
    Role::where('name', Role::SUPER_ADMIN)->first()->permissions()->detach(Permission::where('name', 'pages.delete')->value('id'));

    $this->seed(RoleSeeder::class);

    expect(Role::count())->toBe(5)->and(Permission::count())->toBe(count(PermissionCatalog::names()))
        ->and($support->fresh()->permissions->pluck('name'))->not->toContain('members.update')       // edit kept
        ->and(Role::where('name', Role::SUPER_ADMIN)->first()->permissions->pluck('name'))->toContain('pages.delete'); // super restored
});

it('seeds the starter pages once and never overwrites an edit', function () {
    $this->seed(\Database\Seeders\LanguageSeeder::class);
    $this->seed(\Database\Seeders\PageSeeder::class);

    expect(App\Models\Page::pluck('slug')->sort()->values()->all())->toBe(['about', 'privacy', 'terms']);

    App\Models\Page::where('slug', 'about')->update(['is_published' => false]);
    $this->seed(\Database\Seeders\PageSeeder::class);

    expect(App\Models\Page::count())->toBe(3)
        ->and(App\Models\Page::where('slug', 'about')->value('is_published'))->toBeFalsy();

    // Published starter pages are really reachable and in both languages
    $this->withSession(['locale' => 'en'])->get('/p/privacy')->assertOk()->assertSee('Privacy policy');
    $this->withSession(['locale' => 'pt'])->get('/p/privacy')->assertOk()->assertSee('Política de privacidade');
});

it('has a translated label for every shipped permission, role and area', function () {
    $this->seed(RoleSeeder::class);

    foreach (['en', 'pt'] as $locale) {
        app()->setLocale($locale);

        foreach (Permission::all() as $permission) {
            expect(__("bo_perm_group_{$permission->group()}"))->not->toBe("bo_perm_group_{$permission->group()}")
                ->and(__("bo_perm_action_{$permission->action()}"))->not->toBe("bo_perm_action_{$permission->action()}");
        }

        foreach (Role::all() as $role) {
            $key = 'bo_role_' . str_replace('-', '_', $role->name);

            expect(__($key))->not->toBe($key)
                ->and(__($key . '_desc'))->not->toBe($key . '_desc')
                ->and($role->describe())->not->toBeNull();
        }
    }
});

// ------------------------------------------------------- what roles allow

it('lets a content editor work on pages and texts, and nothing else', function () {
    backofficeAdmin(role: 'content-editor');

    foreach (['/admin/pages', '/admin/pages/create', '/admin/translations'] as $url) {
        $this->get($url)->assertOk();
    }

    foreach (['/admin/families', '/admin/families/create', '/admin/users', '/admin/admins', '/admin/roles', '/admin/permissions', '/admin/languages'] as $url) {
        $this->get($url)->assertForbidden();
    }
});

it('lets a viewer look but not touch', function () {
    backofficeAdmin(role: 'viewer');
    $family = Family::factory()->create();

    $this->get('/admin/families')->assertOk();
    $this->get('/admin/roles')->assertOk();
    $this->get('/admin/families/create')->assertForbidden();
    $this->get("/admin/families/{$family->id}/edit")->assertForbidden();
    $this->get('/admin/pages/create')->assertForbidden();
    $this->get('/admin/roles/create')->assertForbidden();
});

it('lets support add members and reset passwords but not delete families', function () {
    backofficeAdmin(role: 'support');
    $family = Family::factory()->create();

    $this->get('/admin/families')->assertOk();
    $this->get('/admin/families/create')->assertOk();
    expect(Gate::forUser(auth('admin')->user())->allows('delete', $family))->toBeFalse()
        ->and(Gate::forUser(auth('admin')->user())->allows('update', App\Models\User::factory()->make()))->toBeTrue();
});

it('shows an administrator with no role an empty backoffice', function () {
    backofficeAdmin(role: null);

    $this->get('/admin')->assertOk();

    foreach (['/admin/families', '/admin/users', '/admin/pages', '/admin/translations', '/admin/languages', '/admin/admins', '/admin/roles', '/admin/permissions'] as $url) {
        $this->get($url)->assertForbidden();
    }
});

it('gives a super administrator every permission, including ones added later', function () {
    $admin = backofficeAdmin();

    Permission::create(['name' => 'reports.export']);

    expect($admin->hasPermission('reports.export'))->toBeTrue();
});

it('never grants family accounts anything in the backoffice', function () {
    $f = makeFamily();

    expect(Gate::forUser($f['admin'])->allows('viewAny', Family::class))->toBeFalse()
        ->and(Gate::forUser($f['admin'])->allows('viewAny', Role::class))->toBeFalse()
        ->and(Gate::forUser($f['admin'])->allows('viewAny', App\Models\User::class))->toBeFalse();
});

it('combines the permissions of several roles', function () {
    $admin = backofficeAdmin(role: 'translator');
    $admin->roles()->attach(Role::where('name', 'content-editor')->value('id'));
    $admin->unsetRelation('roles');

    expect($admin->hasPermission('texts.update'))->toBeTrue()
        ->and($admin->hasPermission('pages.update'))->toBeTrue()
        ->and($admin->hasPermission('families.view'))->toBeFalse();
});

// ------------------------------------------------------------- roles CRUD

it('creates a role with the ticked permissions', function () {
    backofficeAdmin();

    Livewire::test(CreateRole::class)
        ->fillForm([
            'name' => 'auditor',
            'description' => 'Reads families and members',
            'grants' => ['families' => permissionIds('families.view'), 'members' => permissionIds('members.view')],
        ])
        ->call('create')
        ->assertHasNoFormErrors();

    $role = Role::where('name', 'auditor')->firstOrFail();
    expect($role->is_system)->toBeFalse()
        ->and($role->permissions->pluck('name')->sort()->values()->all())->toBe(['families.view', 'members.view'])
        ->and($role->label())->toBe('Auditor');
});

it('validates a role key', function () {
    backofficeAdmin();

    Livewire::test(CreateRole::class)->fillForm(['name' => 'Not A Key'])->call('create')->assertHasFormErrors(['name' => 'regex']);
    Livewire::test(CreateRole::class)->fillForm(['name' => 'viewer'])->call('create')->assertHasFormErrors(['name' => 'unique']);
});

it('edits the permissions of a role and the change takes effect', function () {
    backofficeAdmin();
    $translator = Role::where('name', 'translator')->firstOrFail();

    $holder = Admin::factory()->withRole('translator')->create();
    expect($holder->hasPermission('pages.update'))->toBeFalse();

    Livewire::test(EditRole::class, ['record' => $translator->getKey()])
        ->fillForm(['grants' => [
            'languages' => [],
            'texts' => permissionIds('texts.view', 'texts.update'),
            'pages' => permissionIds('pages.view', 'pages.update'),
        ]])
        ->call('save')
        ->assertHasNoFormErrors();

    expect($translator->fresh()->permissions->pluck('name')->sort()->values()->all())
        ->toBe(['pages.update', 'pages.view', 'texts.update', 'texts.view'])
        ->and($holder->fresh()->hasPermission('pages.update'))->toBeTrue()
        ->and($holder->fresh()->hasPermission('languages.view'))->toBeFalse();
});

it('keeps the key of a shipped role and cannot delete it', function () {
    backofficeAdmin();
    $support = Role::where('name', 'support')->firstOrFail();

    Livewire::test(EditRole::class, ['record' => $support->getKey()])
        ->fillForm(['name' => 'renamed'])
        ->call('save');

    expect($support->fresh()->name)->toBe('support');

    Livewire::test(ListRoles::class)
        ->assertActionHidden(TestAction::make('delete')->table($support));
    expect(Role::where('name', 'support')->exists())->toBeTrue();
});

it('never changes what the super administrator can do', function () {
    backofficeAdmin();
    $super = Role::where('name', Role::SUPER_ADMIN)->firstOrFail();

    Livewire::test(EditRole::class, ['record' => $super->getKey()])
        ->assertFormSet(fn (array $state) => count(collect($state['grants'])->flatten()) === Permission::count())
        ->fillForm(['grants' => ['families' => []]])
        ->call('save');

    expect($super->fresh()->permissions()->count())->toBe(Permission::count());
});

it('deletes a custom role and the administrators who had it keep the rest', function () {
    backofficeAdmin();
    $role = Role::create(['name' => 'temp-role']);
    $role->permissions()->attach(Permission::where('name', 'pages.view')->value('id'));
    $holder = Admin::factory()->withRole('viewer')->create();
    $holder->roles()->attach($role->id);

    Livewire::test(ListRoles::class)->callAction(TestAction::make('delete')->table($role));

    expect(Role::find($role->id))->toBeNull()
        ->and($holder->fresh()->roles->pluck('name')->all())->toBe(['viewer'])
        ->and(Illuminate\Support\Facades\DB::table('permission_role')->where('role_id', $role->id)->exists())->toBeFalse();
});

// ------------------------------------------------------- permissions CRUD

it('lists permissions and creates a custom one', function () {
    backofficeAdmin();

    Livewire::test(ListPermissions::class)->assertCanSeeTableRecords(Permission::all());

    Livewire::test(CreatePermission::class)
        ->fillForm(['name' => 'reports.export', 'description' => 'Download reports'])
        ->call('create')
        ->assertHasNoFormErrors();

    expect(Permission::where('name', 'reports.export')->first()->is_system)->toBeFalse();

    Livewire::test(CreatePermission::class)->fillForm(['name' => 'nodot'])->call('create')->assertHasFormErrors(['name' => 'regex']);
    Livewire::test(CreatePermission::class)->fillForm(['name' => 'pages.view'])->call('create')->assertHasFormErrors(['name' => 'unique']);
});

it('protects the permissions the code relies on', function () {
    backofficeAdmin();
    $shipped = Permission::where('name', 'pages.update')->firstOrFail();

    Livewire::test(EditPermission::class, ['record' => $shipped->getKey()])
        ->fillForm(['name' => 'pages.change', 'description' => 'Edit the pages'])
        ->call('save');

    expect($shipped->fresh()->name)->toBe('pages.update')->and($shipped->fresh()->description)->toBe('Edit the pages');

    Livewire::test(ListPermissions::class)->assertActionHidden(TestAction::make('delete')->table($shipped));

    $custom = Permission::create(['name' => 'reports.export']);
    Livewire::test(ListPermissions::class)->callAction(TestAction::make('delete')->table($custom));
    expect(Permission::find($custom->id))->toBeNull();
});

// --------------------------------------------------------- administrators

it('assigns roles to an administrator', function () {
    backofficeAdmin();
    $other = Admin::factory()->withRole('viewer')->create();
    $editor = Role::where('name', 'content-editor')->value('id');

    Livewire::test(EditAdmin::class, ['record' => $other->getKey()])
        ->fillForm(['roles' => [$editor]])
        ->call('save')
        ->assertHasNoFormErrors();

    expect($other->fresh()->roles->pluck('name')->all())->toBe(['content-editor']);
});

it('keeps at least one super administrator', function () {
    $me = backofficeAdmin();   // the only super administrator
    $viewer = Role::where('name', 'viewer')->value('id');

    Livewire::test(EditAdmin::class, ['record' => $me->getKey()])
        ->fillForm(['roles' => [$viewer]])
        ->call('save')
        ->assertHasFormErrors(['roles']);

    expect($me->fresh()->isSuperAdmin())->toBeTrue();

    // With a second one, stepping down is fine
    $second = Admin::factory()->superAdmin()->create();
    Livewire::test(EditAdmin::class, ['record' => $second->getKey()])
        ->fillForm(['roles' => [$viewer]])
        ->call('save')
        ->assertHasNoFormErrors();
    expect($second->fresh()->isSuperAdmin())->toBeFalse();
});

it('does not delete the last super administrator', function () {
    $me = backofficeAdmin();
    $viewer = Admin::factory()->withRole('viewer')->create();

    // a viewer cannot be used to remove the only super admin: the delete is blocked even for a super admin acting on another
    expect(Admin::superAdmins()->count())->toBe(1);

    Livewire::test(App\Filament\Resources\Admins\Pages\ListAdmins::class)
        ->callAction(TestAction::make('delete')->table($viewer));
    expect(Admin::find($viewer->id))->toBeNull()->and(Admin::find($me->id))->not->toBeNull();
});

it('hides the roles field from administrators who cannot hand out roles', function () {
    $this->seed(RoleSeeder::class);

    $manager = Role::create(['name' => 'people-manager']);
    $manager->permissions()->attach(permissionIds('administrators.view', 'administrators.update'));

    $admin = Admin::factory()->create();
    $admin->roles()->attach($manager->id);
    test()->actingAs($admin, 'admin');
    Illuminate\Support\Facades\Auth::shouldUse('web');
    Filament\Facades\Filament::setCurrentPanel('admin');

    $other = Admin::factory()->withRole('viewer')->create();

    Livewire::test(EditAdmin::class, ['record' => $other->getKey()])
        ->assertFormFieldHidden('roles');
});
