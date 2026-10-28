<?php

use App\Filament\Resources\Translations\Pages\ListTranslations;
use App\Models\Language;
use App\Models\Translation;
use App\Support\Translations\TranslationRepository;
use Database\Seeders\DatabaseSeeder;
use Filament\Actions\Testing\TestAction;
use Illuminate\Support\Facades\Cache;
use Livewire\Livewire;

beforeEach(function () {
    $this->seed(DatabaseSeeder::class);
    backofficeAdmin();
    Cache::flush();
});

function ptRow(string $key): Translation
{
    return Translation::where('locale', 'pt')->where('key', $key)->firstOrFail();
}

it('creates one row per text and language', function () {
    $keys = count(TranslationRepository::fileLines('pt'));

    expect(Translation::where('locale', 'pt')->count())->toBe($keys)
        ->and(Translation::where('locale', 'en')->count())->toBe($keys);
});

it('shows the default text until someone overrides it', function () {
    app()->setLocale('pt');
    expect(__('login'))->toBe('Entrar');

    ptRow('login')->update(['value' => 'Iniciar sessão']);

    expect(__('login'))->toBe('Iniciar sessão');
});

it('only changes the language that was edited', function () {
    ptRow('login')->update(['value' => 'Iniciar sessão']);

    app()->setLocale('en');
    expect(__('login'))->toBe('Log in');
});

it('goes back to the default when the override is blanked or reset', function () {
    $row = ptRow('login');
    $row->update(['value' => 'Iniciar sessão']);
    $row->update(['value' => '']);
    app()->setLocale('pt');
    expect(__('login'))->toBe('Entrar');

    $row->update(['value' => 'Outra']);
    Livewire::test(ListTranslations::class)
        ->callAction(TestAction::make('reset')->table($row));

    expect($row->fresh()->value)->toBeNull();
    expect(__('login'))->toBe('Entrar');
});

it('edits a text inline from the backoffice table', function () {
    $row = ptRow('login');

    Livewire::test(ListTranslations::class)
        ->searchTable('login')
        ->assertCanSeeTableRecords([$row])
        ->call('updateTableColumnState', 'value', (string) $row->getKey(), 'Acesso');

    expect($row->fresh()->value)->toBe('Acesso');
    app()->setLocale('pt');
    expect(__('login'))->toBe('Acesso');
});

it('refuses an edit that drops a :placeholder the message needs', function () {
    $row = ptRow('login_throttled');   // "...dentro de :seconds segundos."

    Livewire::test(ListTranslations::class)
        ->call('updateTableColumnState', 'value', (string) $row->getKey(), 'Demasiadas tentativas.');

    expect($row->fresh()->value)->toBeNull();

    Livewire::test(ListTranslations::class)
        ->call('updateTableColumnState', 'value', (string) $row->getKey(), 'Aguarda :seconds s.');

    expect($row->fresh()->value)->toBe('Aguarda :seconds s.');
});

it('applies an override to the page people actually see', function () {
    ptRow('login_help')->update(['value' => 'Fala com o administrador da tua família.']);

    $this->withSession(['locale' => 'pt'])->get('/login')
        ->assertOk()
        ->assertSee('Fala com o administrador da tua família.');
});

it('does not touch the framework\'s own PHP translation files', function () {
    Translation::create(['locale' => 'en', 'key' => 'validation.required', 'value' => 'HACKED']);
    app()->setLocale('en');

    expect(__('validation.required'))->not->toBe('HACKED');
});

it('keeps existing edits when syncing and only adds what is missing', function () {
    $row = ptRow('login');
    $row->update(['value' => 'Mine']);
    Translation::where('locale', 'pt')->where('key', 'logout')->delete();

    $created = TranslationRepository::sync();

    expect($created)->toBe(1)
        ->and(ptRow('login')->value)->toBe('Mine')
        ->and(TranslationRepository::sync())->toBe(0);
});

it('filters to the texts that were changed and to one language', function () {
    $row = ptRow('login');
    $row->update(['value' => 'Changed']);

    Livewire::test(ListTranslations::class)
        ->filterTable('customised')
        ->assertCanSeeTableRecords([$row])
        ->assertCountTableRecords(1)
        ->resetTableFilters()
        ->filterTable('locale', 'en')
        ->assertCanNotSeeTableRecords([$row]);
});

it('can sync from the backoffice', function () {
    Translation::where('locale', 'pt')->where('key', 'logout')->delete();

    Livewire::test(ListTranslations::class)->callAction('sync');

    expect(Translation::where('locale', 'pt')->where('key', 'logout')->exists())->toBeTrue();
});

it('does not allow creating rows by hand', function () {
    expect(App\Filament\Resources\Translations\TranslationResource::canCreate())->toBeFalse();
});
