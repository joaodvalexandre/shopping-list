<?php

namespace App\Http\Controllers;

/**
 * The overview: where the shopping stands across every list the person may see. (The Shopping
 * List page is where the lists are; this is what is in the cart, what is still to buy, and how
 * far each list has got.)
 */
class DashboardController extends Controller
{
    /** How many of the items still to buy are shown. */
    private const TO_BUY_SHOWN = 8;

    public function index()
    {
        $lists = ShoppingListController::listsWithStats(auth()->user());

        // Every item with the list it is in, so the page can say where it belongs
        $items = $lists->flatMap(fn ($list) => $list->items->each(fn ($item) => $item->setRelation('shoppingList', $list)));

        $inCart = $items->filter(fn ($item) => $item->status?->code === 'in_cart')->sortBy(fn ($item) => [$item->shoppingList->name, $item->name])->values();
        $toBuy = $items->filter(fn ($item) => $item->status?->code === 'to_buy')->sortByDesc('created_at')->values();

        // Lists with something in them, the nearest to done first
        $progress = $lists->filter(fn ($list) => $list->total > 0)
            ->sortByDesc(fn ($list) => ($list->purchased + $list->in_cart) / $list->total)
            ->values();

        return view('dashboard', [
            'lists' => $lists,
            'totals' => [
                'lists' => $lists->count(),
                'pending' => $lists->sum('pending'),
                'in_cart' => $lists->sum('in_cart'),
                'purchased' => $lists->sum('purchased'),
            ],
            'inCart' => $inCart,
            'toBuy' => $toBuy->take(self::TO_BUY_SHOWN),
            'toBuyMore' => max(0, $toBuy->count() - self::TO_BUY_SHOWN),
            'progress' => $progress,
        ]);
    }
}
