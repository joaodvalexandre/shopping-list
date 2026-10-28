<?php

namespace App\Filament\Support;

use App\Enums\FamilyRole;
use App\Models\User;
use App\Support\TemporaryPassword;
use Filament\Actions\Action;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Support\Icons\Heroicon;
use Illuminate\Support\HtmlString;

/**
 * The things an app admin can do to a family member, shared by every screen
 * that lists members so they behave identically.
 */
class MemberActions
{
    /**
     * Show a temporary password once. There is no email: the admin passes it on.
     * Stays on screen until dismissed, so it cannot be missed.
     */
    public static function showTemporaryPassword(string $email, string $password): void
    {
        Notification::make()
            ->success()
            ->persistent()
            ->title(__('bo_temp_password_title'))
            ->body(new HtmlString(
                e(__('temporary_password_notice')) . '<br><strong>' . e($email) . '</strong>: '
                . '<code style="user-select:all">' . e($password) . '</code>'
            ))
            ->send();
    }

    public static function resetPassword(): Action
    {
        return Action::make('resetPassword')
            ->label(fn () => __('reset_password'))
            ->icon(Heroicon::OutlinedKey)
            ->color('warning')
            ->requiresConfirmation()
            ->modalDescription(fn () => __('confirm_reset_password'))
            ->action(function (User $record) {
                $temporary = TemporaryPassword::generate();

                $record->update(['password' => $temporary, 'must_change_password' => true]);
                $record->forceFill(['remember_token' => null])->save();
                $record->tokens()->delete(); // signed out of every phone too

                static::showTemporaryPassword($record->email, $temporary);
            });
    }

    public static function signOutEverywhere(): Action
    {
        return Action::make('signOutEverywhere')
            ->label(fn () => __('bo_sign_out_everywhere'))
            ->icon(Heroicon::OutlinedArrowRightStartOnRectangle)
            ->requiresConfirmation()
            ->modalDescription(fn () => __('bo_sign_out_everywhere_confirm'))
            ->action(function (User $record) {
                $count = $record->tokens()->count();
                $record->tokens()->delete();
                $record->forceFill(['remember_token' => null])->save();

                Notification::make()->success()->title(__('bo_signed_out', ['count' => $count]))->send();
            });
    }

    /**
     * Name, email and role: what an app admin may change about a member.
     * (Permissions per list type are the family admin's job, in the web app.)
     *
     * @return list<\Filament\Schemas\Components\Component>
     */
    public static function fields(): array
    {
        return [
            TextInput::make('name')
                ->label(fn () => __('name'))
                ->required()
                ->maxLength(255),
            TextInput::make('email')
                ->label(fn () => __('email'))
                ->email()
                ->required()
                ->maxLength(255)
                ->unique(table: 'users', column: 'email', ignoreRecord: true),
            Select::make('role')
                ->label(fn () => __('role'))
                ->options(collect(FamilyRole::cases())->mapWithKeys(fn (FamilyRole $role) => [$role->value => $role->label()])->all())
                ->default(FamilyRole::Member->value)
                ->required()
                ->native(false),
        ];
    }

    /** Edit a member, but never demote the only admin their family has. */
    public static function edit(): EditAction
    {
        return EditAction::make()
            ->before(function (EditAction $action, array $data, User $record) {
                if (($data['role'] ?? null) !== FamilyRole::Admin->value && $record->isLastFamilyAdmin()) {
                    Notification::make()->danger()->title(__('last_admin_error'))->send();
                    $action->halt();
                }
            });
    }

    /** Delete a member, but never the only admin their family has. */
    public static function delete(): DeleteAction
    {
        return DeleteAction::make()
            ->before(function (DeleteAction $action, User $record) {
                if ($record->isLastFamilyAdmin()) {
                    Notification::make()->danger()->title(__('last_admin_error'))->send();
                    $action->halt();
                }
            });
    }
}
