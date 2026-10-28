<?php

namespace App\Filament\Resources\Roles;

use App\Filament\Resources\Roles\Pages\CreateRole;
use App\Filament\Resources\Roles\Pages\EditRole;
use App\Filament\Resources\Roles\Pages\ListRoles;
use App\Models\Permission;
use App\Models\Role;
use BackedEnum;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\CheckboxList;
use Filament\Forms\Components\TextInput;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Callout;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;

/** What each kind of backoffice administrator is allowed to do. */
class RoleResource extends Resource
{
    protected static ?string $model = Role::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedUserGroup;

    protected static ?int $navigationSort = 91;

    protected static ?string $recordTitleAttribute = 'name';

    public static function getNavigationGroup(): ?string
    {
        return __('bo_group_access');
    }

    public static function getModelLabel(): string
    {
        return __('bo_role');
    }

    public static function getPluralModelLabel(): string
    {
        return __('bo_roles');
    }

    public static function getRecordTitle(?Model $record): ?string
    {
        return $record instanceof Role ? $record->label() : null;
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make()->columnSpanFull()->schema([
                TextInput::make('name')
                    ->label(fn () => __('bo_role_key'))
                    ->helperText(fn () => __('bo_role_key_help'))
                    ->required()
                    ->maxLength(60)
                    ->regex('/^[a-z0-9]+(-[a-z0-9]+)*$/')
                    ->unique(ignoreRecord: true)
                    // Shipped roles keep their key: their names are translated by it
                    ->disabled(fn (?Role $record) => $record?->is_system)
                    ->dehydrated(fn (?Role $record) => ! $record?->is_system),
                TextInput::make('description')
                    ->label(fn () => __('bo_description'))
                    ->maxLength(255)
                    ->visible(fn (?Role $record) => ! $record?->is_system),
            ])->columns(2),

            Callout::make(fn () => __('bo_super_admin_note_title'))
                ->description(fn () => __('bo_super_admin_note'))
                ->info()
                ->visible(fn (?Role $record) => $record?->isSuperAdmin()),

            // One box per area, each listing what can be done in it
            ...static::permissionSections(),
        ]);
    }

    /** @return list<Section> */
    private static function permissionSections(): array
    {
        // In the order they were seeded: the areas and actions as the catalog lists them
        return Permission::query()->orderBy('id')->get()
            ->groupBy(fn (Permission $permission) => $permission->group())
            ->map(fn ($permissions, string $group) => Section::make($permissions->first()->groupLabel())
                ->compact()
                ->schema([
                    CheckboxList::make("grants.{$group}")
                        ->hiddenLabel()
                        ->options($permissions->mapWithKeys(fn (Permission $permission) => [
                            $permission->id => $permission->actionLabel(),
                        ])->all())
                        ->columns(4)
                        ->bulkToggleable()
                        // The super administrator has everything, always
                        ->disabled(fn (?Role $record) => $record?->isSuperAdmin()),
                ]))
            ->values()
            ->all();
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('label')
                    ->label(fn () => __('bo_role'))
                    ->state(fn (Role $record) => $record->label())
                    ->description(fn (Role $record) => $record->describe())
                    ->wrap()
                    ->weight('medium')
                    ->searchable(['name', 'description'])
                    ->sortable(query: fn ($query, string $direction) => $query->orderBy('name', $direction)),
                TextColumn::make('name')
                    ->label(fn () => __('bo_role_key'))
                    ->fontFamily('mono')
                    ->color('gray')
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('permissions_count')
                    ->label(fn () => __('bo_permissions'))
                    ->counts('permissions')
                    ->badge()
                    ->color('gray')
                    ->sortable(),
                TextColumn::make('admins_count')
                    ->label(fn () => __('bo_admins'))
                    ->counts('admins')
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
            ->recordActions([
                EditAction::make(),
                DeleteAction::make()
                    ->modalDescription(fn () => __('bo_delete_role_warning')),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListRoles::route('/'),
            'create' => CreateRole::route('/create'),
            'edit' => EditRole::route('/{record}/edit'),
        ];
    }
}
