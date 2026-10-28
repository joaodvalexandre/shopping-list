<?php

namespace App\Models;

use Filament\Auth\MultiFactor\App\Contracts\HasAppAuthentication;
use Filament\Auth\MultiFactor\App\Contracts\HasAppAuthenticationRecovery;
use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use SensitiveParameter;

/**
 * A backoffice administrator (the "app admin"). Not a family member: family
 * accounts live in `users` and use the `web` guard; these use the `admin` guard.
 */
class Admin extends Authenticatable implements FilamentUser, HasAppAuthentication, HasAppAuthenticationRecovery
{
    use HasFactory;

    protected $fillable = ['name', 'email', 'password'];

    protected $hidden = [
        'password',
        'remember_token',
        'app_authentication_secret',
        'app_authentication_recovery_codes',
    ];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'last_login_at' => 'datetime',
            'app_authentication_secret' => 'encrypted',
            'app_authentication_recovery_codes' => 'encrypted:array',
        ];
    }

    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(Role::class);
    }

    /** The super administrator role can do everything, now and for anything added later. */
    public function isSuperAdmin(): bool
    {
        return $this->roles->contains(fn (Role $role) => $role->isSuperAdmin());
    }

    /** @param  string  $permission  "<group>.<action>", e.g. "pages.update" */
    public function hasPermission(string $permission): bool
    {
        if ($this->isSuperAdmin()) {
            return true;
        }

        return $this->loadMissing('roles.permissions')
            ->roles
            ->contains(fn (Role $role) => $role->permissions->contains('name', $permission));
    }

    /** Administrators who hold the super administrator role. */
    public static function superAdmins(): Builder
    {
        return static::whereHas('roles', fn (Builder $query) => $query->where('name', Role::SUPER_ADMIN));
    }

    /** Every row in `admins` is a backoffice administrator. */
    public function canAccessPanel(Panel $panel): bool
    {
        return true;
    }

    public function getAppAuthenticationSecret(): ?string
    {
        return $this->app_authentication_secret;
    }

    public function saveAppAuthenticationSecret(#[SensitiveParameter] ?string $secret): void
    {
        $this->app_authentication_secret = $secret;
        $this->save();
    }

    public function getAppAuthenticationHolderName(): string
    {
        return $this->email;
    }

    public function getAppAuthenticationRecoveryCodes(): ?array
    {
        return $this->app_authentication_recovery_codes;
    }

    public function saveAppAuthenticationRecoveryCodes(#[SensitiveParameter] ?array $codes): void
    {
        $this->app_authentication_recovery_codes = $codes;
        $this->save();
    }
}
