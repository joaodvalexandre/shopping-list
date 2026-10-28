<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Support\Str;

/** One thing a backoffice administrator may do, named "<group>.<action>". */
class Permission extends Model
{
    protected $fillable = ['name', 'description', 'is_system'];

    protected function casts(): array
    {
        return ['is_system' => 'boolean'];
    }

    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(Role::class);
    }

    public function group(): string
    {
        return Str::before($this->name, '.');
    }

    public function action(): string
    {
        return Str::contains($this->name, '.') ? Str::after($this->name, '.') : '';
    }

    public function groupLabel(): string
    {
        return static::translateOr("bo_perm_group_{$this->group()}", Str::headline($this->group()));
    }

    /** e.g. "Edit". Shipped permissions are translated; custom ones show their key. */
    public function actionLabel(): string
    {
        $action = $this->action();

        return $action === '' ? $this->name : static::translateOr("bo_perm_action_{$action}", Str::headline($action));
    }

    /** e.g. "Pages: Edit" */
    public function label(): string
    {
        return $this->action() === '' ? $this->name : $this->groupLabel() . ': ' . $this->actionLabel();
    }

    private static function translateOr(string $key, string $fallback): string
    {
        $text = __($key);

        return $text === $key ? $fallback : $text;
    }
}
