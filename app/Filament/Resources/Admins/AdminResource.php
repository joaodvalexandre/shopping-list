<?php

namespace App\Filament\Resources\Admins;

use App\Filament\Resources\Admins\Pages\CreateAdmin;
use App\Filament\Resources\Admins\Pages\EditAdmin;
use App\Filament\Resources\Admins\Pages\ListAdmins;
use App\Models\Admin;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

/** The people who can sign in to this backoffice. */
class AdminResource extends Resource
{
    protected static ?string $model = Admin::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedShieldCheck;

    protected static ?int $navigationSort = 90;

    protected static ?string $recordTitleAttribute = 'name';

    public static function getNavigationGroup(): ?string
    {
        return __('bo_group_system');
    }

    public static function getModelLabel(): string
    {
        return __('bo_admin');
    }

    public static function getPluralModelLabel(): string
    {
        return __('bo_admins');
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('name')
                ->label(fn () => __('name'))
                ->required()
                ->maxLength(255),
            TextInput::make('email')
                ->label(fn () => __('email'))
                ->email()
                ->required()
                ->maxLength(255)
                ->unique(ignoreRecord: true),
            TextInput::make('password')
                ->label(fn () => __('password'))
                ->password()
                ->revealable()
                ->required(fn (string $operation) => $operation === 'create')
                ->minLength(12)
                ->helperText(fn (string $operation) => $operation === 'edit' ? __('bo_password_keep_help') : __('bo_password_min_help'))
                // On edit, leaving it blank keeps the current password
                ->dehydrated(fn ($state) => filled($state)),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')->label(fn () => __('name'))->searchable()->sortable(),
                TextColumn::make('email')->label(fn () => __('email'))->searchable(),
                IconColumn::make('two_factor')
                    ->label(fn () => __('bo_two_factor'))
                    ->boolean()
                    ->state(fn (Admin $record) => filled($record->app_authentication_secret)),
                TextColumn::make('last_login_at')
                    ->label(fn () => __('bo_last_login'))
                    ->since()
                    ->placeholder(fn () => __('bo_never'))
                    ->sortable(),
            ])
            ->defaultSort('name')
            ->recordActions([
                EditAction::make(),

                // For someone who lost their authenticator: they set it up again at next sign-in
                Action::make('resetTwoFactor')
                    ->label(fn () => __('bo_reset_two_factor'))
                    ->icon(Heroicon::OutlinedKey)
                    ->color('warning')
                    ->requiresConfirmation()
                    ->modalDescription(fn () => __('bo_reset_two_factor_confirm'))
                    ->visible(fn (Admin $record) => filled($record->app_authentication_secret))
                    ->action(function (Admin $record) {
                        $record->forceFill([
                            'app_authentication_secret' => null,
                            'app_authentication_recovery_codes' => null,
                        ])->save();

                        Notification::make()->success()->title(__('bo_two_factor_reset'))->send();
                    }),

                // Never yourself, never the last one: that would lock everybody out
                DeleteAction::make()
                    ->hidden(fn (Admin $record) => $record->is(auth('admin')->user()))
                    ->before(function (DeleteAction $action) {
                        if (Admin::count() <= 1) {
                            Notification::make()->danger()->title(__('bo_last_admin_error'))->send();
                            $action->halt();
                        }
                    }),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListAdmins::route('/'),
            'create' => CreateAdmin::route('/create'),
            'edit' => EditAdmin::route('/{record}/edit'),
        ];
    }
}
