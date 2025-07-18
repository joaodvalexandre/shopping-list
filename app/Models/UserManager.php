<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserManager extends Model
{
    // You don't usually need to define a model for the pivot table, but it's useful if you want to add extra attributes to the pivot.
    protected $table = 'user_manager'; // Set the table name

    // If you want to add extra attributes in the pivot table, you can define them here.
    protected $fillable = ['user_id', 'manager_id'];

    // Define the inverse relationships (if you want to reference users directly from the pivot model)
    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function manager()
    {
        return $this->belongsTo(User::class, 'manager_id');
    }
}
