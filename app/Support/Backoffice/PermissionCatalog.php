<?php

namespace App\Support\Backoffice;

/**
 * Every permission the backoffice code checks, as "<group>.<action>".
 * The seeder turns this into rows; the policies check the same names.
 */
class PermissionCatalog
{
    /** @return array<string, list<string>> group => actions */
    public static function groups(): array
    {
        $crud = ['view', 'create', 'update', 'delete'];

        return [
            'families' => $crud,
            'members' => $crud,        // "update" also covers reset password / sign out everywhere
            'pages' => $crud,
            'menus' => $crud,        // the links of the navbar and footer
            'languages' => $crud,
            'texts' => ['view', 'update'],
            'administrators' => $crud,
            'roles' => $crud,
            'permissions' => $crud,
        ];
    }

    /** @return list<string> */
    public static function names(): array
    {
        $names = [];

        foreach (static::groups() as $group => $actions) {
            foreach ($actions as $action) {
                $names[] = "{$group}.{$action}";
            }
        }

        return $names;
    }

    /** The shipped roles and what they may do. "super-admin" always has everything. */
    public static function roles(): array
    {
        $viewOnly = array_values(array_filter(static::names(), fn (string $name) => str_ends_with($name, '.view')));

        return [
            'super-admin' => static::names(),
            'support' => ['families.view', 'families.create', 'members.view', 'members.create', 'members.update'],
            'content-editor' => ['pages.view', 'pages.create', 'pages.update', 'pages.delete', 'menus.view', 'menus.create', 'menus.update', 'menus.delete', 'texts.view', 'texts.update'],
            'translator' => ['languages.view', 'texts.view', 'texts.update'],
            'viewer' => $viewOnly,
        ];
    }
}
