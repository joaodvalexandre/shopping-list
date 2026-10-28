<?php

namespace App\Filament\Resources\Users;

use App\Enums\FamilyRole;
use App\Filament\Resources\Users\Pages\CreateUser;
use App\Filament\Resources\Users\Pages\EditUser;
use App\Filament\Resources\Users\Pages\ListUsers;
use App\Filament\Support\MemberActions;
use App\Models\User;
use BackedEnum;
use Filament\Actions\ActionGroup;
use Filament\Forms\Components\Select;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

/** Family members across every family. */
class UserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedUsers;

    protected static ?int $navigationSort = 2;

    protected static ?string $recordTitleAttribute = 'name';

    public static function getNavigationGroup(): ?string
    {
        return __('bo_group_families');
    }

    public static function getModelLabel(): string
    {
        return __('bo_member');
    }

    public static function getPluralModelLabel(): string
    {
        return __('bo_members');
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            // Choose the family when creating; it cannot be changed afterwards
            // (permissions and lists belong to the family).
            Select::make('family_id')
                ->label(fn () => __('bo_family'))
                ->relationship('family', 'name')
                ->searchable()
                ->preload()
                ->required()
                ->visibleOn('create'),
            ...MemberActions::fields(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn (Builder $query) => $query->with('family'))
            ->columns([
                TextColumn::make('name')->label(fn () => __('name'))->searchable()->sortable(),
                TextColumn::make('email')->label(fn () => __('email'))->searchable()->copyable(),
                TextColumn::make('family.name')->label(fn () => __('bo_family'))->searchable()->sortable(),
                TextColumn::make('role')
                    ->label(fn () => __('role'))
                    ->badge()
                    ->formatStateUsing(fn ($state) => $state->label())
                    ->color(fn ($state) => $state->value === 'admin' ? 'primary' : 'gray'),
                TextColumn::make('must_change_password')
                    ->label(fn () => __('status'))
                    ->badge()
                    ->formatStateUsing(fn ($state) => $state ? __('pending_first_login') : __('active'))
                    ->color(fn ($state) => $state ? 'warning' : 'success'),
                TextColumn::make('last_login_at')
                    ->label(fn () => __('bo_last_login'))
                    ->since()
                    ->placeholder(fn () => __('bo_never'))
                    ->sortable(),
                TextColumn::make('created_at')
                    ->label(fn () => __('bo_created'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('name')
            ->filters([
                SelectFilter::make('family_id')
                    ->label(fn () => __('bo_family'))
                    ->relationship('family', 'name')
                    ->searchable()
                    ->preload(),
                SelectFilter::make('role')
                    ->label(fn () => __('role'))
                    ->options(collect(FamilyRole::cases())->mapWithKeys(fn (FamilyRole $role) => [$role->value => $role->label()])->all()),
                TernaryFilter::make('must_change_password')
                    ->label(fn () => __('pending_first_login')),
            ])
            ->recordActions([
                MemberActions::edit(),
                ActionGroup::make([
                    MemberActions::resetPassword(),
                    MemberActions::signOutEverywhere(),
                    MemberActions::delete(),
                ]),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListUsers::route('/'),
            'create' => CreateUser::route('/create'),
            'edit' => EditUser::route('/{record}/edit'),
        ];
    }
}
