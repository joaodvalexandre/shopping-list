<?php

namespace App\Http\Controllers;

use App\Models\ShoppingLists;
use App\Models\Status;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Response;

class ShoppingListsController extends Controller
{
    public function index()
    {
        $shoppingList = ShoppingLists::with('status')->get();
        return view('shopping_list.index', compact('shoppingList'));
    }

    public function create()
    {
        $status = Status::all();

        return view('shopping_list.create', compact('status'));
    }

    public function store(Request $request)
    {
        $validatedData = $request->validate([
            'item_id' => 'required',
            'quantity' => 'required|integer|min:1',
            'status_id' => 'sometimes|exists:status,id',
        ]);

        // Set default status to "to buy" (assuming its ID is 1)
        if (!isset($validatedData['status_id'])) {
            $validatedData['status_id'] = 1; // ID for "to buy" status
        }

        ShoppingLists::create($validatedData);

        $this->notificationToggle('item_created_success', 'success');
        return redirect()->route('shopping_list.index')->with('success', 'Item added successfully.');
    }

    public function changeStatus($id, $status)
    {
        $item = ShoppingLists::find($id);
        $allowedTransitions = [
            1 => [2], // From "To Buy" to "In Cart"
            2 => [3, 6], // From "In Cart" to "Purchased" or "Cancelled"
        ];

        if (!isset($allowedTransitions[$item->status_id]) || !in_array($status, $allowedTransitions[$item->status_id])) {
            return back();
        }

        $item->status_id = $status;
        $item->save();

        $statusMessages = [
            2 => 'moved_to_cart',
            3 => 'marked_as_purchased',
            6 => 'cancelled'
        ];

        $messageKey = $statusMessages[$status] ?? 'status_changed';
        $this->notificationToggle($messageKey, ($status != 6) ? 'success' : 'warning');
        return back();
    }

    public function edit(ShoppingLists $shoppingList)
    {
        $status = Status::all();
        $canEdit = $shoppingList->status->code !== 'to_buy';
        return view('shopping_list.edit', compact('shoppingList', 'status', 'canEdit'));
    }

    public function update(Request $request, ShoppingLists $shoppingList)
    {
        $rules = [
            'status_id' => 'sometimes|exists:status,id',
        ];

        // Only allow editing name and quantity if the status is "to buy"
        if ($shoppingList->status->code === 'to_buy') {
            $rules['name'] = 'required|max:255';
            $rules['quantity'] = 'required|integer|min:1';
        }

        $validatedData = $request->validate($rules);

        $shoppingList->update($validatedData);

        $this->notificationToggle('item_updated_success', 'success');
        return redirect()->route('shopping_list.index')->with('success', 'Item updated successfully.');
    }

    public function destroy(ShoppingLists $shoppingList)
    {
        $shoppingList->delete();
        $this->notificationToggle('item_destroyed_success', 'success');
        return redirect()->route('shopping_list.index')->with('success', 'Item deleted successfully.');
    }

    public function export()
    {
        $shoppingList = ShoppingLists::all(['name', 'quantity']);

        $content = $shoppingList->map(function ($item) {
            return $item->name . ' - ' . $item->quantity;
        })->implode("\n");

        return response($content)
            ->header('Content-Type', 'text/plain')
            ->header('Content-Disposition', 'attachment; filename="shopping_list.txt"');
    }
}
