<?php

namespace App\Filament\Widgets;

use Filament\Widgets\Widget;
use Illuminate\Support\Facades\DB;

/** Where this backoffice is running: handy when something misbehaves. */
class SystemInfo extends Widget
{
    protected static ?int $sort = 3;

    protected string $view = 'filament.widgets.system-info';

    /** @return array<string, string> */
    public function rows(): array
    {
        return [
            __('bo_sys_environment') => app()->environment(),
            __('bo_sys_app') => config('app.name'),
            'Laravel' => app()->version(),
            'PHP' => PHP_VERSION,
            __('bo_sys_database') => DB::connection()->getDriverName(),
            __('bo_sys_cache') => config('cache.default'),
            __('bo_sys_queue') => config('queue.default'),
            __('bo_sys_realtime') => config('broadcasting.default'),
        ];
    }
}
