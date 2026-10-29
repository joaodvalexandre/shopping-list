<?php

use App\Filament\Resources\MenuItems\Pages\CreateMenuItem;
use App\Filament\Resources\MenuItems\Pages\EditMenuItem;
use App\Filament\Resources\MenuItems\Pages\ListMenuItems;
use App\Models\MenuItem;
use App\Models\Page;
use App\Models\User;
use App\Support\Menus\AppScreens;
use Database\Seeders\LanguageSeeder;
use Database\Seeders\MenuSeeder;
use Database\Seeders\PageSeeder;
use Filament\Actions\Testing\TestAction;
use Laravel\Sanctum\Sanctum;
use Livewire\Livewire;

beforeEach(function () {
    $this->seed(LanguageSeeder::class);
});

function aboutPage(array $attributes = []): Page
{
    return Page::create($attributes + [
        'slug' => 'about',
        'title' => ['pt' => 'Sobre', 'en' => 'About'],
        'content' => ['pt' => '<p>x</p>', 'en' => '<p>x</p>'],
        'is_published' => true,
    ]);
}

// ----------------------------------------------------------- what is shown

it('shows each link only to the audience it is meant for', function () {
    $about = aboutPage();
    MenuItem::create(['location' => 'navbar', 'page_id' => $about->id, 'audience' => 'everyone', 'sort' => 1]);
    MenuItem::create(['location' => 'navbar', 'screen' => 'login', 'audience' => 'guests', 'sort' => 2]);
    MenuItem::create(['location' => 'navbar', 'screen' => 'dashboard', 'audience' => 'members', 'sort' => 3]);
    MenuItem::create(['location' => 'navbar', 'screen' => 'family_members', 'audience' => 'family_admins', 'sort' => 4]);

    $labels = fn ($user) => MenuItem::tree('navbar', $user)->map->labelIn('en')->all();

    $f = makeFamily();
    $member = memberWith($f['family'], $f['groceries'], ['can_view']);

    expect($labels(null))->toBe(['About', 'Log in'])
        ->and($labels($member))->toBe(['About', 'Dashboard'])
        ->and($labels($f['admin']))->toBe(['About', 'Dashboard', 'Family']);
});

it('draws the navbar and the account menu from the links, in order, for whoever is looking', function () {
    MenuItem::create(['location' => 'navbar', 'screen' => 'shopping_lists', 'audience' => 'members', 'sort' => 1]);
    MenuItem::create(['location' => 'navbar', 'screen' => 'family_members', 'audience' => 'family_admins', 'sort' => 2]);
    MenuItem::create(['location' => 'user_menu', 'screen' => 'settings', 'audience' => 'members', 'sort' => 1]);

    $f = makeFamily();
    $member = memberWith($f['family'], $f['groceries'], ['can_view']);

    $page = $this->actingAs($f['admin'])->withSession(['locale' => 'en'])->get('/dashboard')->assertOk();
    $page->assertSee('Shopping List')->assertSee('Family')->assertSee('Settings')->assertSee(route('family.members.index'), false);

    $page = $this->actingAs($member)->withSession(['locale' => 'en'])->get('/dashboard')->assertOk();
    $page->assertSee('Shopping List')->assertDontSee(route('family.members.index'), false);
});

it('never leaves someone signed in without a way around, even with no navbar links', function () {
    $f = makeFamily();

    expect(MenuItem::count())->toBe(0);

    $this->actingAs($f['admin'])->withSession(['locale' => 'en'])->get('/shopping_list')->assertOk()
        ->assertSee(route('dashboard'), false)
        ->assertSee(route('shopping_list.index'), false);
});

it('leaves out inactive links, drafts, unknown screens and empty headings', function () {
    $draft = aboutPage(['slug' => 'draft', 'is_published' => false]);

    MenuItem::create(['location' => 'footer', 'page_id' => $draft->id]);
    MenuItem::create(['location' => 'footer', 'url' => 'https://example.com', 'label' => ['pt' => 'Off', 'en' => 'Off'], 'is_active' => false]);
    MenuItem::create(['location' => 'footer', 'screen' => 'no-such-screen', 'audience' => 'everyone']);
    MenuItem::create(['location' => 'footer', 'label' => ['pt' => 'Vazio', 'en' => 'Empty']]);   // a heading with nothing under it
    MenuItem::create(['location' => 'footer', 'url' => 'https://example.com', 'label' => ['pt' => 'Visível', 'en' => 'Visible']]);

    expect(MenuItem::tree('footer')->map->labelIn('en')->all())->toBe(['Visible']);
});

it('puts links under a heading to make a column, and keeps them in the heading\'s place', function () {
    $heading = MenuItem::create(['location' => 'footer', 'label' => ['pt' => 'Legal', 'en' => 'Legal']]);
    $privacy = aboutPage(['slug' => 'privacy', 'title' => ['pt' => 'Privacidade', 'en' => 'Privacy']]);
    $child = MenuItem::create(['location' => 'navbar', 'parent_id' => $heading->id, 'page_id' => $privacy->id]);

    expect($child->fresh()->location)->toBe('footer');   // follows its parent

    $tree = MenuItem::tree('footer');
    expect($tree)->toHaveCount(1)->and($tree->first()->children->map->labelIn('en')->all())->toBe(['Privacy']);

    $heading->update(['location' => 'navbar']);
    expect($child->fresh()->location)->toBe('navbar');   // moves with it

    $this->get('/login')->assertOk()->assertSee('Legal')->assertSee('Privacidade');
});

it('only offers a screen to the audiences it is meant for', function () {
    $dashboard = MenuItem::create(['location' => 'navbar', 'screen' => 'dashboard', 'audience' => 'everyone']);
    $login = MenuItem::create(['location' => 'navbar', 'screen' => 'login', 'audience' => 'members']);

    expect($dashboard->fresh()->audience)->toBe('members')       // the dashboard is not for visitors
        ->and($login->fresh()->audience)->toBe('guests');        // nor is "log in" for people already in
});

// ---------------------------------------------------------------- safety

it('never links to an address that could run a script', function () {
    foreach (['javascript:alert(1)', 'data:text/html,<script>1</script>', '//evil.example', 'ftp://x', 'not a url', ' '] as $bad) {
        expect(MenuItem::safeUrl($bad))->toBeNull();
    }

    expect(MenuItem::safeUrl('https://example.com/a?b=1'))->toBe('https://example.com/a?b=1')
        ->and(MenuItem::safeUrl('/p/about'))->toBe(url('/p/about'));

    // and one that was saved anyway is simply not drawn
    MenuItem::create(['location' => 'footer', 'url' => 'javascript:alert(1)', 'label' => ['pt' => 'Mau', 'en' => 'Evil']]);
    $this->get('/login')->assertOk()->assertDontSee('javascript:alert')->assertDontSee('Mau');
});

it('opens links in a new tab safely', function () {
    MenuItem::create(['location' => 'footer', 'url' => 'https://example.com', 'label' => ['pt' => 'Fora', 'en' => 'Out'], 'new_tab' => true]);

    $this->get('/login')->assertOk()->assertSee('target="_blank"', false)->assertSee('noopener noreferrer', false);
});

// ------------------------------------------------------------ backoffice

it('creates a link to a page, a screen and an address from the form', function () {
    backofficeAdmin();
    $about = aboutPage();

    Livewire::test(CreateMenuItem::class)
        ->fillForm(['location' => 'footer', 'target' => 'page', 'page_id' => $about->id, 'audience' => 'everyone'])
        ->call('create')->assertHasNoFormErrors();

    Livewire::test(CreateMenuItem::class)
        ->fillForm(['location' => 'user_menu', 'target' => 'screen', 'screen' => 'settings', 'audience' => 'members'])
        ->call('create')->assertHasNoFormErrors();

    Livewire::test(CreateMenuItem::class)
        ->fillForm(['location' => 'navbar', 'target' => 'link', 'url' => 'https://example.com', 'audience' => 'everyone', 'label' => ['pt' => 'Exemplo', 'en' => 'Example']])
        ->call('create')->assertHasNoFormErrors();

    expect(MenuItem::pluck('location')->sort()->values()->all())->toBe(['footer', 'navbar', 'user_menu'])
        ->and(MenuItem::where('screen', 'settings')->first()->kind())->toBe('screen')
        ->and(MenuItem::where('url', 'https://example.com')->first()->labelIn('en'))->toBe('Example');
});

it('validates what a link points at', function () {
    backofficeAdmin();

    Livewire::test(CreateMenuItem::class)
        ->fillForm(['location' => 'footer', 'target' => 'link', 'url' => 'javascript:alert(1)', 'audience' => 'everyone', 'label' => ['pt' => 'x', 'en' => 'x']])
        ->call('create')->assertHasFormErrors(['url']);

    Livewire::test(CreateMenuItem::class)
        ->fillForm(['location' => 'footer', 'target' => 'link', 'audience' => 'everyone'])
        ->call('create')->assertHasFormErrors(['url' => 'required']);

    Livewire::test(CreateMenuItem::class)
        ->fillForm(['location' => 'footer', 'target' => 'page', 'audience' => 'everyone'])
        ->call('create')->assertHasFormErrors(['page_id' => 'required']);

    Livewire::test(CreateMenuItem::class)
        ->fillForm(['location' => 'footer', 'target' => 'heading', 'audience' => 'everyone'])
        ->call('create')->assertHasFormErrors(['label.pt' => 'required']);

    expect(MenuItem::count())->toBe(0);
});

it('clears the old target when a link is changed to point somewhere else', function () {
    backofficeAdmin();
    $about = aboutPage();
    $item = MenuItem::create(['location' => 'footer', 'page_id' => $about->id]);

    Livewire::test(EditMenuItem::class, ['record' => $item->getKey()])
        ->assertFormSet(['target' => 'page'])
        ->fillForm(['target' => 'link', 'url' => 'https://example.com', 'label' => ['pt' => 'Fora', 'en' => 'Out']])
        ->call('save')->assertHasNoFormErrors();

    $item = $item->fresh();
    expect($item->page_id)->toBeNull()->and($item->url)->toBe('https://example.com')->and($item->kind())->toBe('link');
});

it('keeps two levels at most and moves nothing under itself', function () {
    backofficeAdmin();
    $heading = MenuItem::create(['location' => 'footer', 'label' => ['pt' => 'A', 'en' => 'A']]);
    MenuItem::create(['location' => 'footer', 'parent_id' => $heading->id, 'url' => 'https://example.com', 'label' => ['pt' => 'B', 'en' => 'B']]);

    // the heading already holds a link, so it cannot go under another heading
    Livewire::test(EditMenuItem::class, ['record' => $heading->getKey()])
        ->assertFormFieldDisabled('parent_id');
});

it('lists, hides and deletes links', function () {
    backofficeAdmin();
    $item = MenuItem::create(['location' => 'footer', 'url' => 'https://example.com', 'label' => ['pt' => 'Fora', 'en' => 'Out']]);

    Livewire::test(ListMenuItems::class)->assertCanSeeTableRecords([$item])->callAction(TestAction::make('delete')->table($item));

    expect(MenuItem::find($item->id))->toBeNull();
});

it('lets a content editor arrange menus', function () {
    backofficeAdmin(role: 'content-editor');

    $this->get('/admin/menu-items')->assertOk();
    $this->get('/admin/menu-items/create')->assertOk();
});

it('lets a viewer look at the menus but not change them', function () {
    backofficeAdmin(role: 'viewer');

    $this->get('/admin/menu-items')->assertOk();
    $this->get('/admin/menu-items/create')->assertForbidden();
});

it('deletes the links of a page when the page is deleted', function () {
    $about = aboutPage();
    MenuItem::create(['location' => 'footer', 'page_id' => $about->id]);

    $about->delete();

    expect(MenuItem::count())->toBe(0);
});

// ------------------------------------------------------------------- seeder

it('seeds starter links once and never puts back what was changed', function () {
    $this->seed(PageSeeder::class);
    $this->seed(MenuSeeder::class);

    expect(MenuItem::tree('navbar', null)->map->labelIn('en')->all())->toBe(['About'])
        ->and(MenuItem::tree('footer')->map->labelIn('en')->all())->toBe(['Information', 'Legal'])
        ->and(MenuItem::where('location', 'user_menu')->count())->toBe(2)
        ->and(MenuItem::where('screen', 'dashboard')->exists())->toBeTrue();

    // Arranged by hand: the starter links are not put back, only added when there are none at all
    MenuItem::where('location', '!=', 'footer')->delete();
    $before = MenuItem::count();
    $this->seed(MenuSeeder::class);

    expect(MenuItem::count())->toBe($before)->and(MenuItem::where('screen', 'dashboard')->exists())->toBeFalse();
});

// --------------------------------------------------------------------- api

it('shows a page in the language the app asks for', function () {
    aboutPage();

    $this->get('/p/about?lang=en')->assertOk()->assertSee('About');
    $this->get('/p/about?lang=pt')->assertOk()->assertSee('Sobre');
});
