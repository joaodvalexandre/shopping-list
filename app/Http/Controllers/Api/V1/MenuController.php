<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Language;
use App\Models\MenuItem;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * The navbar, account menu and footer links arranged in the backoffice, for the
 * phone app to show the same pages and addresses. Public (the sign-in screen has
 * a footer too); the app's own web screens are left out, the app has its own.
 */
class MenuController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $locale = $request->query('locale');
        $locale = is_string($locale) && Language::isActive($locale) ? $locale : Language::defaultCode();

        app()->setLocale($locale);

        // A phone that is signed in sees what its person may see (the token is optional here)
        $user = $request->user('sanctum');

        return response()->json([
            'locale' => $locale,
            'navbar' => $this->present(MenuItem::tree(MenuItem::NAVBAR, $user), $locale),
            'user_menu' => $this->present(MenuItem::tree(MenuItem::USER_MENU, $user), $locale),
            'footer' => $this->present(MenuItem::tree(MenuItem::FOOTER, $user), $locale),
        ]);
    }

    /** @return list<array<string, mixed>> */
    private function present($items, string $locale): array
    {
        // Web screens (dashboard, lists...) mean nothing on the phone; it has its own
        return $items->filter(fn (MenuItem $item) => $item->screen === null)->map(fn (MenuItem $item) => [
            'label' => $item->labelIn($locale),
            // A page opens in the reader's language
            'url' => $item->page_id && $item->href() ? $item->href() . '?lang=' . $locale : $item->href(),
            'new_tab' => $item->new_tab,
            'children' => $item->relationLoaded('children') ? $this->present($item->children, $locale) : [],
        ])->filter(fn (array $item) => $item['url'] !== null || $item['children'] !== [])->values()->all();
    }
}
