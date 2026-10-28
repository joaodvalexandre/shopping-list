<?php

namespace App\Filament\Widgets;

use App\Filament\Resources\Families\FamilyResource;
use App\Models\Family;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget;

class LatestFamilies extends TableWidget
{
    protected static ?int $sort = 2;

    protected int|string|array $columnSpan = 'full';

    public function table(Table $table): Table
    {
        return $table
            ->heading(fn () => __('bo_latest_families'))
            ->query(fn () => Family::query()->withCount(['users', 'shoppingLists'])->latest()->limit(5))
            ->columns([
                TextColumn::make('name')->label(fn () => __('name')),
                TextColumn::make('users_count')->label(fn () => __('bo_members')),
                TextColumn::make('shopping_lists_count')->label(fn () => __('lists')),
                TextColumn::make('created_at')->label(fn () => __('bo_created'))->since(),
            ])
            ->recordUrl(fn (Family $record) => FamilyResource::getUrl('edit', ['record' => $record]))
            ->paginated(false);
    }
}
