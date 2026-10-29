<?php

use App\Models\MenuItem;
use App\Models\Page;
use App\Models\Translation;
use Database\Seeders\LanguageSeeder;
use Database\Seeders\MenuSeeder;
use Database\Seeders\PageSeeder;

beforeEach(function () {
    $this->seed(LanguageSeeder::class);
});

it('gives the phone its languages, texts, pages and links, with no token', function () {
    $this->seed(PageSeeder::class);
    $this->seed(MenuSeeder::class);

    $response = $this->getJson('/api/v1/content')->assertOk()
        ->assertJsonPath('languages.0.code', 'pt')
        ->assertJsonPath('languages.0.is_default', true)
        ->assertJsonPath('texts.en.login', 'Log in')
        ->assertJsonPath('texts.pt.login', 'Entrar');

    expect($response->json('version'))->toBeString()->not->toBe('')
        ->and(collect($response->json('pages'))->pluck('slug')->all())->toBe(['about', 'privacy', 'terms'])
        ->and($response->json('pages.1.title.en'))->toBe('Privacy policy')
        ->and($response->json('pages.1.title.pt'))->toBe('Política de privacidade')
        ->and($response->json('pages.1.content.en'))->toContain('<h2')
        ->and($response->json('pages.1.content.pt'))->toContain('Que dados guardamos');
});

it('sends every link with its audience and a label per language, but not the web screens', function () {
    $this->seed(PageSeeder::class);
    $this->seed(MenuSeeder::class);

    $menu = collect($this->getJson('/api/v1/content')->json('menu'));

    // the dashboard and the like are the web's own screens: the phone has its own
    expect($menu->where('page', null)->where('url', null)->pluck('label.en')->all())->not->toContain('Dashboard');

    $privacy = $menu->firstWhere('page', 'privacy');
    expect($privacy['location'])->toBe('footer')
        ->and($privacy['label']['en'])->toBe('Privacy policy')
        ->and($privacy['label']['pt'])->toBe('Política de privacidade')
        ->and($privacy['audience'])->toBe('everyone')
        ->and($privacy['parent_id'])->not->toBeNull();

    $heading = $menu->firstWhere('id', $privacy['parent_id']);
    expect($heading['page'])->toBeNull()->and($heading['url'])->toBeNull();
});

it('leaves out links to drafts and unsafe addresses', function () {
    $draft = Page::create(['slug' => 'draft', 'title' => ['pt' => 'Rascunho'], 'content' => ['pt' => '<p>x</p>'], 'is_published' => false]);
    MenuItem::create(['location' => 'footer', 'page_id' => $draft->id]);
    MenuItem::create(['location' => 'footer', 'url' => 'javascript:alert(1)', 'label' => ['pt' => 'Mau']]);
    MenuItem::create(['location' => 'footer', 'url' => 'https://example.com', 'label' => ['pt' => 'Bom', 'en' => 'Good'], 'new_tab' => true]);

    $response = $this->getJson('/api/v1/content')->assertOk();

    expect($response->json('pages'))->toBe([])
        ->and(collect($response->json('menu'))->pluck('label.pt')->all())->toBe(['Bom'])
        ->and($response->json('menu.0.url'))->toBe('https://example.com')
        ->and($response->json('menu.0.new_tab'))->toBeTrue();
});

it('includes the texts edited in the backoffice', function () {
    Translation::updateOrCreate(['locale' => 'en', 'key' => 'login'], ['value' => 'Come in']);

    $this->getJson('/api/v1/content')->assertJsonPath('texts.en.login', 'Come in')->assertJsonPath('texts.pt.login', 'Entrar');
});

it('says nothing changed when the phone already has this version, and sends it all again when it moved', function () {
    $this->seed(PageSeeder::class);

    $version = $this->getJson('/api/v1/content')->json('version');

    $this->getJson("/api/v1/content?version={$version}")->assertOk()
        ->assertExactJson(['version' => $version, 'unchanged' => true]);

    Page::where('slug', 'about')->update(['content' => json_encode(['pt' => '<p>Novo</p>', 'en' => '<p>New</p>'])]);

    $fresh = $this->getJson("/api/v1/content?version={$version}")->assertOk();
    expect($fresh->json('unchanged'))->toBeNull()->and($fresh->json('version'))->not->toBe($version)
        ->and($fresh->json('pages.0.content.en'))->toContain('New');
});
