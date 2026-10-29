<?php

namespace App\Support\Menus;

use Illuminate\Support\Facades\Route;

/**
 * The web app's own screens that a menu link can point at, next to content
 * pages and free addresses. Each says which routes make it "the current one"
 * and who may be shown the link (the server protects the screen itself either way).
 */
class AppScreens
{
    public const EVERYONE = 'everyone';

    public const GUESTS = 'guests';

    public const MEMBERS = 'members';           // anyone signed in

    public const FAMILY_ADMINS = 'family_admins';

    /** @return array<string, array{route: string, label: string, active: list<string>, audiences: list<string>}> */
    public static function all(): array
    {
        return [
            'dashboard' => [
                'route' => 'dashboard',
                'label' => 'dashboard',
                'active' => ['dashboard'],
                'audiences' => [self::MEMBERS, self::FAMILY_ADMINS],
            ],
            'shopping_lists' => [
                'route' => 'shopping_list.index',
                'label' => 'shopping_list',
                'active' => ['shopping_list*', 'item*'],
                'audiences' => [self::MEMBERS, self::FAMILY_ADMINS],
            ],
            'family_members' => [
                'route' => 'family.members.index',
                'label' => 'family',
                'active' => ['family.members*'],
                'audiences' => [self::FAMILY_ADMINS],
            ],
            'family_list_types' => [
                'route' => 'family.list-types.index',
                'label' => 'list_types',
                'active' => ['family.list-types*'],
                'audiences' => [self::FAMILY_ADMINS],
            ],
            'settings' => [
                'route' => 'settings.edit',
                'label' => 'settings',
                'active' => ['settings*'],
                'audiences' => [self::MEMBERS, self::FAMILY_ADMINS],
            ],
            'login' => [
                'route' => 'login',
                'label' => 'login',
                'active' => ['login'],
                'audiences' => [self::GUESTS],
            ],
        ];
    }

    public static function find(?string $key): ?array
    {
        return $key === null ? null : (static::all()[$key] ?? null);
    }

    /** The URL of a screen, or null when it does not exist (a stale key never breaks a page). */
    public static function url(?string $key): ?string
    {
        $screen = static::find($key);

        return $screen && Route::has($screen['route']) ? route($screen['route']) : null;
    }

    /** @return list<string> every audience a link may have */
    public static function audiences(): array
    {
        return [self::EVERYONE, self::GUESTS, self::MEMBERS, self::FAMILY_ADMINS];
    }

    /** Audiences that make sense for what the link points at. */
    public static function audiencesFor(?string $screenKey): array
    {
        return static::find($screenKey)['audiences'] ?? static::audiences();
    }
}
