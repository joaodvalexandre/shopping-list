<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class VehicleRequest extends Model
{
    use HasFactory;
    protected $casts = [
        'id' => 'integer',
    ];

    /**
     * The attributes that are mass assignable.
     *
     * @var string[]
     */
    protected $fillable = [
        'vehicle_id',
        'user_id',
        'requested_for',
        'status',
        'manager_approval',
        'approval_date',
    ];

    /**
     * Define the relationship with the user who made the request.
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Define the relationship with the requested vehicle.
     */
    public function vehicle()
    {
        return $this->belongsTo(Vehicle::class);
    }

    /**
     * Define the relationship with the requested vehicle.
     */
    public function status()
    {
        return $this->belongsTo(Status::class);
    }

    /**
     * Define the relationship with the requested vehicle.
     */
    public function managerApproval()
    {
        return $this->belongsTo(Status::class);
    }
}
