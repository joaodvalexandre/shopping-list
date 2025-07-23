<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ShoppingList extends Model
{
    protected $fillable = ['name'];

    /**
     * A shopping list has many items.
     */
    public function items()
    {
        return $this->hasMany(Item::class, 'shopping_list_id');
    }

    /**
     * Get total number of items in the list.
     */
    public function getTotalItems()
    {
        return $this->items()->count();
    }

    /**
     * Count items by status name.
     */
    private function getItemsByStatus(string $statusName): int
    {
        return $this->items()
            ->whereHas('status', fn($q) => $q->where('name', $statusName))
            ->count();
    }

    public function getPendingItems(): int
    {
        return $this->getItemsByStatus('to_buy');
    }

    public function getPurchasedItems(): int
    {
        return $this->getItemsByStatus('purchased');
    }

    public function getInCartItems(): int
    {
        return $this->getItemsByStatus('in_cart');
    }

    /**
     * Calculate the dynamic status of the shopping list.
     */
    public function calculateStatus(): array
    {
        $total = $this->getTotalItems();

        if ($total === 0) {
            return ['name' => 'no_items', 'color' => '#6B7280']; // gray
        }

        $toBuy = $this->getPendingItems();
        $inCart = $this->getInCartItems();
        $purchased = $this->getPurchasedItems();

        if ($purchased === $total) {
            return ['name' => 'finished', 'color' => '#4CAF50']; // green
        }

        if ($inCart === $total) {
            return ['name' => 'all_in_cart', 'color' => '#1E90FF']; // blue
        }

        if ($inCart > 0) {
            return ['name' => 'shopping', 'color' => '#FFA500']; // yellow
        }

        if ($toBuy === $total) {
            return ['name' => 'pending', 'color' => '#F97316']; // orange
        }

        return ['name' => 'mixed', 'color' => '#8B5CF6']; // purple
    }
}
