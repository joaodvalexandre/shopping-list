<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Status extends Model
{
    use HasFactory;

    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'status';

    protected $fillable = ['code', 'color'];

    /**
     * Get the color as an HTML style.
     *
     * @return string
     */
    public function getColorStyleAttribute(): string
    {
        return "color: {$this->color};";
    }
}
