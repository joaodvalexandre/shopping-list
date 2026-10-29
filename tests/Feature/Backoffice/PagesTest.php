<?php

use App\Filament\Resources\Pages\Pages\CreatePage;
use App\Filament\Resources\Pages\Pages\EditPage;
use App\Filament\Resources\Pages\Pages\ListPages;
use App\Models\Language;
use App\Models\MenuItem;
use App\Models\Page;
use Database\Seeders\LanguageSeeder;
use Filament\Actions\Testing\TestAction;
use Livewire\Livewire;

beforeEach(function () {
    $this->seed(LanguageSeeder::class);
});

function publishedPage(array $attributes = []): Page
{
    return Page::create($attributes + [
        'slug' => 'about',
        'title' => ['pt' => 'Sobre', 'en' => 'About'],
        'content' => ['pt' => '<p>Texto em português</p>', 'en' => '<p>English text</p>'],
        'is_published' => true,
    ]);
}

// ------------------------------------------------------------ public side

it('shows a published page to anyone, in their language', function () {
    publishedPage();

    $this->withSession(['locale' => 'pt'])->get('/p/about')->assertOk()->assertSee('Sobre')->assertSee('Texto em português');
    $this->withSession(['locale' => 'en'])->get('/p/about')->assertOk()->assertSee('About')->assertSee('English text');
});

it('answers 404 for drafts and unknown pages', function () {
    publishedPage(['slug' => 'secret', 'is_published' => false]);

    $this->get('/p/secret')->assertNotFound();
    $this->get('/p/nothing-here')->assertNotFound();
});

it('falls back to the default language when a translation is missing', function () {
    publishedPage(['slug' => 'only-pt', 'title' => ['pt' => 'Só português', 'en' => ''], 'content' => ['pt' => '<p>Apenas PT</p>', 'en' => '']]);

    $this->withSession(['locale' => 'en'])->get('/p/only-pt')->assertOk()->assertSee('Só português')->assertSee('Apenas PT');
});

it('links the pages put in the footer from the sign-in page and the app', function () {
    $privacy = publishedPage(['slug' => 'privacy', 'title' => ['pt' => 'Privacidade', 'en' => 'Privacy']]);
    $draft = publishedPage(['slug' => 'draft', 'title' => ['pt' => 'Rascunho', 'en' => 'Draft'], 'is_published' => false]);
    publishedPage(['slug' => 'hidden-link', 'title' => ['pt' => 'Escondida', 'en' => 'Hidden']]);

    MenuItem::create(['location' => 'footer', 'page_id' => $privacy->id]);
    MenuItem::create(['location' => 'footer', 'page_id' => $draft->id]);   // a draft is never linked

    $this->get('/login')->assertOk()->assertSee('Privacidade')->assertDontSee('Rascunho')->assertDontSee('Escondida');

    $f = makeFamily();
    $this->actingAs($f['admin'])->get('/dashboard')->assertOk()->assertSee('Privacidade');

    // the page itself is still reachable when not linked
    $this->get('/p/hidden-link')->assertOk();
});

it('does not run scripts that end up in a page', function () {
    publishedPage(['slug' => 'evil', 'content' => ['pt' => '<p>Olá</p><script>alert("xss")</script><img src=x onerror="alert(1)">', 'en' => '']]);

    $response = $this->get('/p/evil')->assertOk()->assertSee('Olá');

    expect($response->getContent())->not->toContain('<script>alert("xss")')
        ->and($response->getContent())->not->toContain('onerror');
});

// ------------------------------------------------------------- backoffice

it('creates a page with a text per language', function () {
    backofficeAdmin();

    Livewire::test(CreatePage::class)
        ->fillForm([
            'slug' => 'terms',
            'is_published' => true,
            'title' => ['pt' => 'Termos', 'en' => 'Terms'],
            'content' => ['pt' => '<p>Os termos</p>', 'en' => '<p>The terms</p>'],
        ])
        ->call('create')
        ->assertHasNoFormErrors();

    $page = Page::where('slug', 'terms')->firstOrFail();
    expect($page->titleIn('en'))->toBe('Terms')->and($page->titleIn('pt'))->toBe('Termos');
    $this->get('/p/terms')->assertOk();
});

it('requires the default language only', function () {
    backofficeAdmin();

    Livewire::test(CreatePage::class)
        ->fillForm(['slug' => 'x', 'title' => ['pt' => '', 'en' => 'Only English'], 'content' => ['pt' => '', 'en' => '<p>x</p>']])
        ->call('create')
        ->assertHasFormErrors(['title.pt', 'content.pt']);

    Livewire::test(CreatePage::class)
        ->fillForm(['slug' => 'y', 'title' => ['pt' => 'Só PT', 'en' => ''], 'content' => ['pt' => '<p>y</p>', 'en' => '']])
        ->call('create')
        ->assertHasNoFormErrors(['title.pt', 'content.pt', 'title.en']);
});

it('only accepts clean, unique addresses', function () {
    backofficeAdmin();
    publishedPage(['slug' => 'about']);

    foreach (['About Us', 'with_underscore', '-lead', 'trail-', 'a/b', '../etc'] as $bad) {
        Livewire::test(CreatePage::class)
            ->fillForm(['slug' => $bad, 'title' => ['pt' => 'T'], 'content' => ['pt' => '<p>c</p>']])
            ->call('create')
            ->assertHasFormErrors(['slug']);
    }

    Livewire::test(CreatePage::class)
        ->fillForm(['slug' => 'about', 'title' => ['pt' => 'T'], 'content' => ['pt' => '<p>c</p>']])
        ->call('create')
        ->assertHasFormErrors(['slug' => 'unique']);
});

it('edits, unpublishes and deletes a page', function () {
    backofficeAdmin();
    $page = publishedPage();

    Livewire::test(EditPage::class, ['record' => $page->getKey()])
        ->fillForm(['title' => ['pt' => 'Novo título', 'en' => 'New title'], 'is_published' => false])
        ->call('save')
        ->assertHasNoFormErrors();

    expect($page->fresh()->titleIn('pt'))->toBe('Novo título');
    $this->get('/p/about')->assertNotFound();

    Livewire::test(ListPages::class)->callAction(TestAction::make('delete')->table($page));
    expect(Page::count())->toBe(0);
});

it('offers a tab for every active language', function () {
    backofficeAdmin();
    Language::create(['code' => 'es', 'name' => 'Spanish', 'native_name' => 'Español', 'is_active' => true]);

    $this->get('/admin/pages/create')->assertOk()->assertSee('Español')->assertSee('English')->assertSee('Português');
});

it('puts a back link at the top of a page: to the login for guests, to the dashboard when signed in', function () {
    publishedPage();

    $guest = $this->withSession(['locale' => 'en'])->get('/p/about')->assertOk();
    $guest->assertSee('Back to log in')->assertSee(route('login'), false);
    // it comes before the page's own title, not after the text
    expect(strpos($guest->getContent(), 'Back to log in'))->toBeLessThan(strpos($guest->getContent(), '<h1'));

    $f = makeFamily();
    $this->actingAs($f['admin'])->withSession(['locale' => 'en'])->get('/p/about')
        ->assertOk()->assertDontSee('Back to dashboard')->assertDontSee('Back to log in');
});

it('shows a page inside the app (navbar, header and middle block) when signed in, and on its own when not', function () {
    publishedPage(['slug' => 'privacy', 'title' => ['pt' => 'Privacidade', 'en' => 'Privacy']]);

    $guest = $this->withSession(['locale' => 'en'])->get('/p/privacy')->assertOk();
    $guest->assertSee('sm:max-w-3xl', false)        // the guest layout's own card
        ->assertSee('<h1', false);

    $f = makeFamily();
    $member = $this->actingAs($f['admin'])->withSession(['locale' => 'en'])->get('/p/privacy')->assertOk();

    $member->assertDontSee('sm:max-w-3xl', false)   // not the login-style card
        ->assertSee('bg-white dark:bg-gray-800 shadow-xs', false)   // the app's middle block
        ->assertSee(route('dashboard'), false)       // the navbar
        ->assertSee('<title>Privacy</title>', false)
        ->assertSee('English text');
    expect(substr_count($member->getContent(), 'Privacy'))->toBeGreaterThanOrEqual(2);   // tab title and the header strip
});
