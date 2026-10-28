<?php

namespace App\Filament\Resources\Translations\Pages;

use App\Filament\Resources\Translations\TranslationResource;
use App\Support\Translations\TranslationRepository;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ListRecords;
use Filament\Support\Icons\Heroicon;

class ListTranslations extends ListRecords
{
    protected static string $resource = TranslationResource::class;

    protected function getHeaderActions(): array
    {
        return [
            // After new texts are added to the app (or a language is switched on),
            // make sure each one has a row to edit. Existing edits are never touched.
            Action::make('sync')
                ->label(fn () => __('bo_sync_texts'))
                ->icon(Heroicon::OutlinedArrowPath)
                ->action(function () {
                    $created = TranslationRepository::sync();

                    Notification::make()->success()->title(__('bo_synced', ['count' => $created]))->send();
                }),
        ];
    }
}
