<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Support\Str;

/** A named set of permissions that can be given to backoffice administrators. */
class Role extends Model
{
    /** Has every permission, always (including ones added later). */
    public const SUPER_ADMIN = 'super-admin';

    protected $fillable = ['name', 'description', 'is_system'];

    protected function casts(): array
    {
        return ['is_system' => 'boolean'];
    }

    public function permissions(): BelongsToMany
    {
        return $this->belongsToMany(Permission::class);
    }

    public function admins(): BelongsToMany
    {
        return $this->belongsToMany(Admin::class);
    }

    public function isSuperAdmin(): bool
    {
        return $this->name === self::SUPER_ADMIN;
    }

    /** Shipped roles are translated; custom ones show the name they were given. */
    public function label(): string
    {
        $key = 'bo_role_' . str_replace('-', '_', $this->name);
        $text = __($key);

        return $text === $key ? Str::headline($this->name) : $text;
    }

    public function describe(): ?string
    {
        $key = 'bo_role_' . str_replace('-', '_', $this->name) . '_desc';
        $text = __($key);

        return $this->is_system && $text !== $key ? $text : $this->description;
    }
}
