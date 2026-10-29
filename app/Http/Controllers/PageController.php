<?php

namespace App\Http\Controllers;

use App\Models\Language;
use App\Models\Page;
use Filament\Forms\Components\RichEditor\RichContentRenderer;
use Illuminate\Http\Request;

class PageController extends Controller
{
    /** Public: a published content page. Drafts answer 404. */
    public function show(Request $request, string $slug)
    {
        // A link from the phone app says which language the reader uses
        $lang = $request->query('lang');
        if (is_string($lang) && Language::isActive($lang)) {
            app()->setLocale($lang);
        }

        $page = Page::published()->where('slug', $slug)->firstOrFail();

        return view('pages.show', [
            'page' => $page,
            'title' => $page->titleIn(),
            // The editor's HTML is passed through Filament's renderer, not echoed raw
            'html' => RichContentRenderer::make($page->contentIn())->toHtml(),
        ]);
    }
}
