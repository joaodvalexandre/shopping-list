<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** One thing that happened on a family list (see the activities migration). */
class Activity extends Model
{
    public const ITEM_ADDED = 'item_added';

    public const ITEM_IN_CART = 'item_in_cart';

    public const ITEM_PURCHASED = 'item_purchased';

    /** Taken out of the cart (or the purchases) and back to be bought. */
    public const ITEM_RETURNED = 'item_returned';

    public const ITEM_REMOVED = 'item_removed';

    /** Renamed, or its quantity changed. */
    public const ITEM_CHANGED = 'item_changed';

    public const LIST_CREATED = 'list_created';

    public $timestamps = false;

    protected $fillable = ['family_id', 'shopping_list_id', 'actor_id', 'kind', 'subject', 'quantity'];

    protected function casts(): array
    {
        return ['created_at' => 'datetime'];
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id');
    }

    public function shoppingList(): BelongsTo
    {
        return $this->belongsTo(ShoppingList::class);
    }
}
