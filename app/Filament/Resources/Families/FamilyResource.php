<?php

namespace App\Filament\Resources\Families;

use App\Filament\Resources\Families\Pages\CreateFamily;
use App\Filament\Resources\Families\Pages\EditFamily;
use App\Filament\Resources\Families\Pages\ListFamilies;
use App\Filament\Resources\Families\RelationManagers\MembersRelationManager;
use App\Models\Family;
use BackedEnum;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\TextInput;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class FamilyResource extends Resource
{
    protected static ?string $model = Family::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedHomeModern;

    protected static ?int $navigationSort = 1;

    protected static ?string $recordTitleAttribute = 'name';

    public static function getNavigationGroup(): ?string
    {
        return __('bo_group_families');
    }

    public static function getModelLabel(): string
    {
        return __('bo_family');
    }

    public static function getPluralModelLabel(): string
    {
        return __('bo_families');
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make()->schema([
                TextInput::make('name')
                    ->label(fn () => __('name'))
                    ->required()
                    ->maxLength(255),
            ]),

            // Only when creating: a family always starts with one admin, who then
            // adds the rest of the family from the web app.
            Section::make(fn () => __('bo_first_admin'))
                ->description(fn () => __('bo_first_admin_help'))
                ->visibleOn('create')
                ->schema([
                    TextInput::make('admin_name')
                        ->label(fn () => __('name'))
                        ->required()
                        ->maxLength(255),
                    TextInput::make('admin_email')
                        ->label(fn () => __('email'))
                        ->email()
                        ->required()
                        ->maxLength(255)
                        ->unique(table: 'users', column: 'email'),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')
                    ->label(fn () => __('name'))
                    ->searchable()
                    ->sortable(),
                TextColumn::make('users_count')
                    ->label(fn () => __('bo_members'))
                    ->counts('users')
                    ->sortable(),
                TextColumn::make('shopping_lists_count')
                    ->label(fn () => __('lists'))
                    ->counts('shoppingLists')
                    ->sortable(),
                TextColumn::make('created_at')
                    ->label(fn () => __('bo_created'))
                    ->since()
                    ->sortable(),
            ])
            ->defaultSort('name')
            ->recordActions([
                EditAction::make(),
                DeleteAction::make()
                    ->modalDescription(fn () => __('bo_delete_family_warning')),
            ]);
    }

    public static function getRelations(): array
    {
        return [
            MembersRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListFamilies::route('/'),
            'create' => CreateFamily::route('/create'),
            'edit' => EditFamily::route('/{record}/edit'),
        ];
    }
}
