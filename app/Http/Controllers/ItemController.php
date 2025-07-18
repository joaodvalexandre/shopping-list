<?php

namespace App\Http\Controllers;

use App\Models\Item;
use App\Models\Status;
use Illuminate\Http\Request;

class ItemController extends Controller
{
    public function index()
    {
        $items = Item::get();
        return view('item.index', compact('items'));
    }

    public function create()
    {
        return view('item.create');
    }

    public function store(Request $request)
    {
        $validatedData = $request->validate([
            'label' => 'required|max:255',
            'translation_pt' => 'max:255',
            'translation_en' => 'max:255',
            'description' => 'string|min:10|max:1000'
        ]);

        // Create array to save on items
        $organized_data = [
            'name' => $validatedData['label']
        ];
        Item::create($validatedData);

        // Create translation for english and portuguese
        $this->addTranslation();
        $this->addTranslation();

        $this->notificationToggle('item_created_success', 'success');
        return redirect()->route('item.index')->with('success', 'item_created_success');
    }

    // public function changeStatus($id, $status)
    // {
    //     $item = ShoppingList::find($id);
    //     $allowedTransitions = [
    //         1 => [2], // From "To Buy" to "In Cart"
    //         2 => [3, 6], // From "In Cart" to "Purchased" or "Cancelled"
    //     ];

    //     if (!isset($allowedTransitions[$item->status_id]) || !in_array($status, $allowedTransitions[$item->status_id])) {
    //         return back();
    //     }

    //     $item->status_id = $status;
    //     $item->save();

    //     $statusMessages = [
    //         2 => 'moved_to_cart',
    //         3 => 'marked_as_purchased',
    //         6 => 'cancelled'
    //     ];

    //     $messageKey = $statusMessages[$status] ?? 'status_changed';
    //     $this->notificationToggle($messageKey, ($status != 6) ? 'success' : 'warning');
    //     return back();
    // }

    // public function edit(ShoppingList $shoppingList)
    // {
    //     $status = Status::all();
    //     $canEdit = $shoppingList->status->code !== 'to_buy';
    //     return view('shopping_list.edit', compact('shoppingList', 'status', 'canEdit'));
    // }

    // public function update(Request $request, ShoppingList $shoppingList)
    // {
    //     $rules = [
    //         'status_id' => 'sometimes|exists:status,id',
    //     ];

    //     // Only allow editing name and quantity if the status is "to buy"
    //     if ($shoppingList->status->code === 'to_buy') {
    //         $rules['name'] = 'required|max:255';
    //         $rules['quantity'] = 'required|integer|min:1';
    //     }

    //     $validatedData = $request->validate($rules);

    //     $shoppingList->update($validatedData);

    //     $this->notificationToggle('item_updated_success', 'success');
    //     return redirect()->route('shopping_list.index')->with('success', 'Item updated successfully.');
    // }

    // public function destroy(ShoppingList $shoppingList)
    // {
    //     $shoppingList->delete();
    //     $this->notificationToggle('item_destroyed_success', 'success');
    //     return redirect()->route('shopping_list.index')->with('success', 'Item deleted successfully.');
    // }

    // public function export()
    // {
    //     $shoppingList = ShoppingList::all(['name', 'quantity']);

    //     $content = $shoppingList->map(function ($item) {
    //         return $item->name . ' - ' . $item->quantity;
    //     })->implode("\n");

    //     return response($content)
    //         ->header('Content-Type', 'text/plain')
    //         ->header('Content-Disposition', 'attachment; filename="shopping_list.txt"');
    // }
}
