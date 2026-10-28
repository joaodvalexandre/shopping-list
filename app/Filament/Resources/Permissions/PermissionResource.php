<?php

namespace App\Filament\Resources\Permissions;

use App\Filament\Resources\Permissions\Pages\CreatePermission;
use App\Filament\Resources\Permissions\Pages\EditPermission;
use App\Filament\Resources\Permissions\Pages\ListPermissions;
use App\Models\Permission;
use BackedEnum;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\TextInput;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * The individual things an administrator can be allowed to do. The ones that
 * ship with the app are checked by the code, so they can be described but not
 * renamed or removed; custom ones can be created for future use.
 */
class PermissionResource extends Resource
{
    protected static ?string $model = Permission::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedKey;

    protected static ?int $navigationSort = 92;

    protected static ?string $recordTitleAttribute = 'name';

    public static function getNavigationGroup(): ?string
    {
        return __('bo_group_access');
    }

    public static function getModelLabel(): string
    {
        return __('bo_permission');
    }

    public static function getPluralModelLabel(): string
    {
        return __('bo_permissions');
    }

    public static function getRecordTitle(?Model $record): ?string
    {
        return $record instanceof Permission ? $record->label() : null;
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make()->schema([
                TextInput::make('name')
                    ->label(fn () => __('bo_permission_key'))
                    ->helperText(fn () => __('bo_permission_key_help'))
                    ->required()
                    ->maxLength(100)
                    ->regex('/^[a-z0-9_]+\.[a-z0-9_]+$/')
                    ->unique(ignoreRecord: true)
                    // The code looks shipped permissions up by this key
                    ->disabled(fn (?Permission $record) => $record?->is_system)
                    ->dehydrated(fn (?Permission $record) => ! $record?->is_system),
                TextInput::make('description')
                    ->label(fn () => __('bo_description'))
                    ->maxLength(255),
            ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('group')
                    ->label(fn () => __('bo_area'))
                    ->state(fn (Permission $record) => $record->groupLabel())
                    ->badge()
                    ->color('gray')
                    ->sortable(query: fn (Builder $query, string $direction) => $query->orderBy('name', $direction)),
                TextColumn::make('action')
                    ->label(fn () => __('bo_action'))
                    ->state(fn (Permission $record) => $record->actionLabel())
                    ->description(fn (Permission $record) => $record->description)
                    ->weight('medium')
                    ->searchable(['name', 'description']),
                TextColumn::make('name')
                    ->label(fn () => __('bo_permission_key'))
                    ->fontFamily('mono')
                    ->color('gray')
                    ->copyable(),
                TextColumn::make('roles_count')
                    ->label(fn () => __('bo_roles'))
                    ->counts('roles')
                    ->badge()
                    ->color('gray')
                    ->sortable(),
                IconColumn::make('is_system')
                    ->label(fn () => __('bo_built_in'))
                    ->boolean()
                    ->trueIcon(Heroicon::OutlinedLockClosed)
                    ->falseIcon(Heroicon::OutlinedMinus)
                    ->trueColor('gray')
                    ->falseColor('gray'),
            ])
            ->defaultSort('name')
            ->defaultPaginationPageOption(50)
            ->filters([
                SelectFilter::make('group')
                    ->label(fn () => __('bo_area'))
                    ->options(fn () => Permission::orderBy('name')->get()
                        ->unique(fn (Permission $permission) => $permission->group())
                        ->mapWithKeys(fn (Permission $permission) => [$permission->group() => $permission->groupLabel()])
                        ->all())
                    ->query(fn (Builder $query, array $data) => filled($data['value'] ?? null)
                        ? $query->where('name', 'like', $data['value'] . '.%')
                        : $query),
            ])
            ->recordActions([
                EditAction::make(),
                DeleteAction::make()
                    ->modalDescription(fn () => __('bo_delete_permission_warning')),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListPermissions::route('/'),
            'create' => CreatePermission::route('/create'),
            'edit' => EditPermission::route('/{record}/edit'),
        ];
    }
}
