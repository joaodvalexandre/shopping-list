<?php

namespace App\Filament\Resources\Families\RelationManagers;

use App\Filament\Support\MemberActions;
use App\Models\User;
use App\Support\TemporaryPassword;
use Filament\Actions\ActionGroup;
use Filament\Actions\CreateAction;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

/** The members of one family, on the family's page. */
class MembersRelationManager extends RelationManager
{
    protected static string $relationship = 'users';

    public static function getTitle(\Illuminate\Database\Eloquent\Model $ownerRecord, string $pageClass): string
    {
        return __('bo_members');
    }

    public function form(Schema $schema): Schema
    {
        return $schema->components(MemberActions::fields());
    }

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('name')
            ->columns([
                TextColumn::make('name')->label(fn () => __('name'))->searchable()->sortable(),
                TextColumn::make('email')->label(fn () => __('email'))->searchable(),
                TextColumn::make('role')
                    ->label(fn () => __('role'))
                    ->badge()
                    ->formatStateUsing(fn ($state) => $state->label())
                    ->color(fn ($state) => $state->value === 'admin' ? 'primary' : 'gray'),
                IconColumn::make('must_change_password')
                    ->label(fn () => __('pending_first_login'))
                    ->boolean(),
                TextColumn::make('last_login_at')
                    ->label(fn () => __('bo_last_login'))
                    ->since()
                    ->placeholder(fn () => __('bo_never'))
                    ->sortable(),
            ])
            ->defaultSort('name')
            ->headerActions([
                CreateAction::make()
                    ->label(fn () => __('new_member'))
                    ->using(function (array $data): User {
                        $temporary = TemporaryPassword::for($this->getOwnerRecord());

                        $member = $this->getOwnerRecord()->users()->create($data + [
                            'password' => $temporary,
                            'must_change_password' => true,
                        ]);

                        MemberActions::showTemporaryPassword($member->email, $temporary);

                        return $member;
                    })
                    ->successNotification(null),
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
}
