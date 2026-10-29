<?php

namespace App\Support\Mobile;

use App\Models\Language;
use App\Models\MenuItem;
use App\Models\Page;
use App\Support\Translations\TranslationRepository;
use Filament\Forms\Components\RichEditor\RichContentRenderer;
use Illuminate\Database\QueryException;

/**
 * Everything the phone app keeps in its own database apart from the family's lists:
 * the languages on offer, every text in each of them, the published content pages
 * and the navbar/account/footer links with who they are for. It is the same for
 * everybody (the app filters links by audience on the phone), so a phone that has it
 * works fully offline, signed in or not.
 */
class MobileContent
{
    /** @return array<string, mixed> */
    public static function build(): array
    {
        $languages = Language::active()->values();
        $codes = $languages->pluck('code')->all() ?: Language::FALLBACK_CODES;

        $payload = [
            'languages' => $languages->map(fn (array $language) => [
                'code' => $language['code'],
                'name' => $language['name'],
                'native_name' => $language['native_name'],
                'is_default' => (bool) $language['is_default'],
            ])->all(),
            'texts' => self::texts($codes),
            'pages' => self::pages($codes),
            'menu' => self::menu($codes),
        ];

        // A fingerprint of the content: the app sends it back and gets "unchanged" when nothing moved
        return ['version' => substr(sha1(json_encode($payload)), 0, 16)] + $payload;
    }

    /**
     * The shipped text of each language with the backoffice's edits on top.
     *
     * @param  list<string>  $codes
     * @return array<string, array<string, string>>
     */
    private static function texts(array $codes): array
    {
        $texts = [];

        foreach ($codes as $code) {
            $texts[$code] = array_filter(
                TranslationRepository::overrides($code) + TranslationRepository::fileLines($code),
                fn ($value) => is_string($value) && $value !== '',
            );
        }

        return $texts;
    }

    /** @return list<array<string, mixed>> */
    private static function pages(array $codes): array
    {
        try {
            $pages = Page::published()->orderBy('sort')->orderBy('id')->get();
        } catch (QueryException) {
            return [];
        }

        return $pages->map(function (Page $page) use ($codes) {
            $title = [];
            $content = [];

            foreach ($codes as $code) {
                $title[$code] = $page->titleIn($code);
                // The editor's HTML goes through Filament's renderer, as on the web
                $content[$code] = (string) RichContentRenderer::make($page->contentIn($code))->toHtml();
            }

            return ['slug' => $page->slug, 'title' => $title, 'content' => $content];
        })->all();
    }

    /**
     * The links, flat, in order. The app's own screens are left out (the phone has its own);
     * so is a link to an unpublished page or to an address that is not safe.
     *
     * @param  list<string>  $codes
     * @return list<array<string, mixed>>
     */
    private static function menu(array $codes): array
    {
        try {
            $items = MenuItem::where('is_active', true)->with('page')->orderBy('sort')->orderBy('id')->get();
        } catch (QueryException) {
            return [];
        }

        return $items->filter(fn (MenuItem $item) => $item->screen === null)->map(function (MenuItem $item) use ($codes) {
            $kind = $item->kind();
            $page = $kind === 'page' && $item->page?->is_published ? $item->page->slug : null;
            $url = $kind === 'link' ? MenuItem::safeUrl($item->url) : null;

            $labels = [];
            foreach ($codes as $code) {
                $labels[$code] = $item->labelIn($code);
            }

            return [
                'id' => $item->id,
                'parent_id' => $item->parent_id,
                'location' => $item->location,
                'audience' => $item->audience,
                'label' => $labels,
                'page' => $page,
                'url' => $url,
                'new_tab' => (bool) $item->new_tab,
                'kind' => $kind,
            ];
        })
            // A link to a page that is not published (or an unsafe address) goes nowhere
            ->filter(fn (array $item) => $item['kind'] === 'heading' || $item['page'] !== null || $item['url'] !== null)
            ->map(fn (array $item) => array_diff_key($item, ['kind' => 1]))
            ->values()->all();
    }
}
