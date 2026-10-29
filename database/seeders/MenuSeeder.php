<?php

namespace Database\Seeders;

use App\Models\MenuItem;
use App\Models\Page;
use App\Support\Menus\AppScreens;
use Illuminate\Database\Seeder;

/**
 * Starter links: the app's own screens in the navbar and account menu (so they
 * can be rearranged, renamed, hidden or given to other people), the About page,
 * and a footer with two columns (information, legal). Only when there are no
 * links at all, so what you arrange or delete in the backoffice is never put back.
 */
class MenuSeeder extends Seeder
{
    public function run(): void
    {
        if (MenuItem::exists()) {
            return;
        }

        $pages = Page::pluck('id', 'slug');

        // The web app's own screens
        $navbar = ['dashboard' => AppScreens::MEMBERS, 'shopping_lists' => AppScreens::MEMBERS, 'family_members' => AppScreens::FAMILY_ADMINS];
        $position = 0;

        foreach ($navbar as $screen => $audience) {
            MenuItem::create(['location' => MenuItem::NAVBAR, 'screen' => $screen, 'audience' => $audience, 'sort' => ++$position]);
        }

        if (isset($pages['about'])) {
            MenuItem::create(['location' => MenuItem::NAVBAR, 'page_id' => $pages['about'], 'sort' => ++$position]);
        }

        MenuItem::create(['location' => MenuItem::USER_MENU, 'screen' => 'settings', 'audience' => AppScreens::MEMBERS, 'sort' => 1]);
        MenuItem::create(['location' => MenuItem::USER_MENU, 'screen' => 'family_list_types', 'audience' => AppScreens::FAMILY_ADMINS, 'sort' => 2]);

        // The footer: two columns of pages
        $columns = [
            ['label' => ['pt' => 'Informação', 'en' => 'Information'], 'pages' => ['about']],
            ['label' => ['pt' => 'Legal', 'en' => 'Legal'], 'pages' => ['privacy', 'terms']],
        ];

        foreach ($columns as $index => $column) {
            $heading = MenuItem::create([
                'location' => MenuItem::FOOTER,
                'label' => $column['label'],
                'sort' => $index + 1,
            ]);

            foreach ($column['pages'] as $order => $slug) {
                if (isset($pages[$slug])) {
                    $heading->children()->create([
                        'location' => MenuItem::FOOTER,
                        'page_id' => $pages[$slug],
                        'sort' => $order + 1,
                    ]);
                }
            }
        }
    }
}
