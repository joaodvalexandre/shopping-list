<?php

namespace App\Filament\Widgets;

use App\Models\Family;
use App\Models\User;
use Filament\Widgets\ChartWidget;

/** New families and new members, month by month, for the last half year. */
class GrowthChart extends ChartWidget
{
    protected static ?int $sort = 2;

    protected ?string $maxHeight = '260px';

    public static function canView(): bool
    {
        return (bool) auth('admin')->user()?->hasPermission('families.view');
    }

    public function getHeading(): ?string
    {
        return __('bo_growth');
    }

    protected function getType(): string
    {
        return 'bar';
    }

    protected function getData(): array
    {
        $months = collect(range(5, 0))->map(fn (int $ago) => now()->startOfMonth()->subMonths($ago));
        $since = $months->first();

        $perMonth = fn (string $model) => $model::query()
            ->where('created_at', '>=', $since)
            ->pluck('created_at')
            ->countBy(fn ($createdAt) => $createdAt->format('Y-m'));

        $families = $perMonth(Family::class);
        $members = $perMonth(User::class);

        return [
            'datasets' => [
                [
                    'label' => __('bo_families'),
                    'data' => $months->map(fn ($month) => $families->get($month->format('Y-m'), 0))->all(),
                    'backgroundColor' => '#6366f1',
                    'borderRadius' => 4,
                ],
                [
                    'label' => __('bo_members'),
                    'data' => $months->map(fn ($month) => $members->get($month->format('Y-m'), 0))->all(),
                    'backgroundColor' => '#a5b4fc',
                    'borderRadius' => 4,
                ],
            ],
            'labels' => $months->map(fn ($month) => $month->locale(app()->getLocale())->translatedFormat('M Y'))->all(),
        ];
    }

    protected function getOptions(): array
    {
        return [
            'plugins' => ['legend' => ['position' => 'bottom']],
            'scales' => ['y' => ['beginAtZero' => true, 'ticks' => ['precision' => 0]]],
        ];
    }
}
