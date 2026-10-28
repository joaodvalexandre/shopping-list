<?php

use App\Filament\Resources\Languages\Pages\CreateLanguage;
use App\Filament\Resources\Languages\Pages\EditLanguage;
use App\Filament\Resources\Languages\Pages\ListLanguages;
use App\Models\Language;
use App\Models\Translation;
use App\Models\User;
use Database\Seeders\LanguageSeeder;
use Filament\Actions\Testing\TestAction;
use Livewire\Livewire;

beforeEach(function () {
    $this->seed(LanguageSeeder::class);
    backofficeAdmin();
});

it('ships with Portuguese as the default and English', function () {
    expect(Language::activeCodes())->toBe(['pt', 'en'])
        ->and(Language::defaultCode())->toBe('pt');
});

it('adds a language, which then appears on the site', function () {
    Livewire::test(CreateLanguage::class)
        ->fillForm(['code' => 'es', 'name' => 'Spanish', 'native_name' => 'Español', 'flag' => 'language-es', 'is_active' => true, 'sort' => 3])
        ->call('create')
        ->assertHasNoFormErrors();

    expect(Language::activeCodes())->toContain('es');

    // visitors can switch to it, and the dropdown offers it
    auth('admin')->logout();
    $this->from('/login')->get('/switch-language/es')->assertRedirect('/login');
    $this->withSession(['locale' => 'es'])->get('/login')->assertOk()->assertSee('Español');
    expect(session('locale'))->toBe('es');
});

it('gives a new language an editable row for every text', function () {
    $this->seed(Database\Seeders\DatabaseSeeder::class);
    $texts = Translation::where('locale', 'pt')->count();

    Language::create(['code' => 'es', 'name' => 'Spanish', 'native_name' => 'Español', 'is_active' => true]);

    expect($texts)->toBeGreaterThan(100)
        ->and(Translation::where('locale', 'es')->count())->toBe($texts);
});

it('validates the language code', function () {
    Livewire::test(CreateLanguage::class)
        ->fillForm(['code' => 'Not A Code!', 'name' => 'X', 'native_name' => 'X'])
        ->call('create')
        ->assertHasFormErrors(['code' => 'regex']);

    Livewire::test(CreateLanguage::class)
        ->fillForm(['code' => 'pt', 'name' => 'Dup', 'native_name' => 'Dup'])
        ->call('create')
        ->assertHasFormErrors(['code' => 'unique']);
});

it('refuses to switch to a language that is not on offer', function () {
    Language::create(['code' => 'es', 'name' => 'Spanish', 'native_name' => 'Español', 'is_active' => false]);
    auth('admin')->logout();

    $this->get('/switch-language/es')->assertStatus(400);
    $this->get('/switch-language/xx')->assertStatus(400);
});

it('falls back to the default language when someone\'s language is switched off', function () {
    $es = Language::create(['code' => 'es', 'name' => 'Spanish', 'native_name' => 'Español', 'is_active' => true]);
    $user = User::factory()->create(['locale' => 'es']);

    $this->actingAs($user)->get('/dashboard');
    expect(app()->getLocale())->toBe('es');

    $es->update(['is_active' => false]);

    $this->actingAs($user)->get('/dashboard');
    expect(app()->getLocale())->toBe('pt');
});

it('keeps exactly one default language, which is always on', function () {
    $en = Language::where('code', 'en')->first();
    $en->update(['is_default' => true]);

    expect(Language::where('is_default', true)->pluck('code')->all())->toBe(['en'])
        ->and(Language::defaultCode())->toBe('en');

    // a default language cannot be switched off
    $en->update(['is_active' => false]);
    expect($en->fresh()->is_active)->toBeTrue();
});

it('never deletes the default or the fallback language', function () {
    $pt = Language::where('code', 'pt')->first();
    $en = Language::where('code', 'en')->first();

    expect($pt->delete())->toBeFalse()->and($en->delete())->toBeFalse();
    expect(Language::count())->toBe(2);

    Livewire::test(ListLanguages::class)
        ->assertActionHidden(TestAction::make('delete')->table($pt))
        ->assertActionHidden(TestAction::make('delete')->table($en));
});

it('deletes another language together with its texts', function () {
    $es = Language::create(['code' => 'es', 'name' => 'Spanish', 'native_name' => 'Español', 'is_active' => true]);
    Translation::where('locale', 'es')->where('key', 'login')->update(['value' => 'Entrar']);
    expect(Translation::where('locale', 'es')->count())->toBeGreaterThan(100);

    Livewire::test(ListLanguages::class)
        ->callAction(TestAction::make('delete')->table($es));

    expect(Language::where('code', 'es')->exists())->toBeFalse()
        ->and(Translation::where('locale', 'es')->count())->toBe(0);
});

it('cannot change a language code after creation', function () {
    $pt = Language::where('code', 'pt')->first();

    Livewire::test(EditLanguage::class, ['record' => $pt->getKey()])
        ->assertFormFieldIsDisabled('code');
});

it('saves a user\'s language from settings only if it is on offer', function () {
    $user = User::factory()->create();
    Language::create(['code' => 'es', 'name' => 'Spanish', 'native_name' => 'Español', 'is_active' => true]);
    Language::create(['code' => 'fr', 'name' => 'French', 'native_name' => 'Français', 'is_active' => false]);

    $this->actingAs($user)->put('/settings/profile', ['name' => 'A', 'email' => 'a@example.com', 'locale' => 'es'])->assertRedirect();
    expect($user->fresh()->locale)->toBe('es');

    $this->actingAs($user)->put('/settings/profile', ['name' => 'A', 'email' => 'a@example.com', 'locale' => 'fr'])->assertSessionHasErrors('locale');
    expect($user->fresh()->locale)->toBe('es');
});
