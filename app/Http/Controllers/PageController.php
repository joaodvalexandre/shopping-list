<?php

namespace App\Http\Controllers;

use App\Models\Page;
use Filament\Forms\Components\RichEditor\RichContentRenderer;

class PageController extends Controller
{
    /** Public: a published content page. Drafts answer 404. */
    public function show(string $slug)
    {
        $page = Page::published()->where('slug', $slug)->firstOrFail();

        return view('pages.show', [
            'page' => $page,
            'title' => $page->titleIn(),
            // The editor's HTML is passed through Filament's renderer, not echoed raw
            'html' => RichContentRenderer::make($page->contentIn())->toHtml(),
        ]);
    }
}
