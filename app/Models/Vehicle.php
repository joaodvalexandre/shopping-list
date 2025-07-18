<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Vehicle extends Model
{
    use HasFactory;

    /**
     * The attributes that are mass assignable.
     *
     * @var string[]
     */
    protected $fillable = [
        'brand',
        'model',
        'license_plate',
        'vin',
        'insurance_number',
        'insurance_date',
    ];

    /**
     * Define the relationship with vehicle requests.
     */
    public function requests()
    {
        return $this->hasMany(VehicleRequest::class);
    }

    public function getFullNameAttribute()
    {
        return "{$this->brand} {$this->model}";
    }

    public function getFullNameWithLicenseAttribute()    {
        return "{$this->brand} {$this->model} ({$this->license_plate})";
    }
}
