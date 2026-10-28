<?php

namespace App\Filament\Widgets;

use App\Models\Family;
use App\Models\Item;
use App\Models\ShoppingList;
use App\Models\User;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class OverviewStats extends StatsOverviewWidget
{
    protected static ?int $sort = 1;

    protected function getStats(): array
    {
        $pending = User::where('must_change_password', true)->count();

        return [
            Stat::make(__('bo_families'), Family::count()),
            Stat::make(__('bo_members'), User::count())
                ->description($pending > 0 ? __('bo_stats_pending', ['count' => $pending]) : null)
                ->color($pending > 0 ? 'warning' : 'success'),
            Stat::make(__('lists'), ShoppingList::count()),
            Stat::make(__('bo_items'), Item::count()),
        ];
    }
}
