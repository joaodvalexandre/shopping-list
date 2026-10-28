<?php

namespace App\Filament\Widgets;

use App\Models\Family;
use App\Models\Item;
use App\Models\ShoppingList;
use App\Models\User;
use Filament\Support\Icons\Heroicon;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Database\Eloquent\Model;

class OverviewStats extends StatsOverviewWidget
{
    protected static ?int $sort = 1;

    protected ?string $pollingInterval = '60s';

    public static function canView(): bool
    {
        return (bool) auth('admin')->user()?->hasPermission('families.view');
    }

    protected function getStats(): array
    {
        $pending = User::where('must_change_password', true)->count();

        return [
            $this->stat(__('bo_families'), Family::class),
            // People who have not signed in yet are what the owner needs to notice
            $this->stat(__('bo_members'), User::class, $pending > 0
                ? [__('bo_stats_pending', ['count' => $pending]), Heroicon::OutlinedClock, 'warning']
                : null),
            $this->stat(__('lists'), ShoppingList::class),
            $this->stat(__('bo_items'), Item::class),
        ];
    }

    /**
     * A total with the number added in the last 14 days as a small trend line.
     *
     * @param  array{0: string, 1: Heroicon, 2: string}|null  $notice  replaces the trend text (description, icon, colour)
     */
    private function stat(string $label, string $model, ?array $notice = null): Stat
    {
        /** @var class-string<Model> $model */
        $since = now()->subDays(13)->startOfDay();

        $perDay = $model::query()
            ->where('created_at', '>=', $since)
            ->pluck('created_at')
            ->countBy(fn ($createdAt) => $createdAt->toDateString());

        $series = collect(range(0, 13))
            ->map(fn (int $offset) => $perDay->get($since->copy()->addDays($offset)->toDateString(), 0))
            ->all();

        $added = array_sum($series);

        [$description, $descriptionIcon, $color] = $notice ?? [
            $added > 0 ? __('bo_stats_added', ['count' => $added]) : __('bo_stats_none_added'),
            $added > 0 ? Heroicon::OutlinedArrowTrendingUp : Heroicon::OutlinedMinus,
            $added > 0 ? 'primary' : 'gray',
        ];

        return Stat::make($label, number_format($model::count()))
            ->description($description)
            ->descriptionIcon($descriptionIcon)
            ->chart($series)
            ->color($color);
    }
}
