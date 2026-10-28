<?php

namespace App\Filament\Resources\Translations;

use App\Filament\Resources\Translations\Pages\ListTranslations;
use App\Models\Language;
use App\Models\Translation;
use App\Support\Translations\TranslationRepository;
use BackedEnum;
use Closure;
use Filament\Actions\Action;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Textarea;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\TextInputColumn;
use Filament\Tables\Filters\Filter;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

/**
 * Every text of the web app, per language. The text that ships with the app is
 * the default; typing a value here overrides it (leave blank to go back to the default).
 */
class TranslationResource extends Resource
{
    protected static ?string $model = Translation::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedQueueList;

    protected static ?int $navigationSort = 30;

    protected static ?string $recordTitleAttribute = 'key';

    public static function getNavigationGroup(): ?string
    {
        return __('bo_group_content');
    }

    public static function getModelLabel(): string
    {
        return __('bo_text');
    }

    public static function getPluralModelLabel(): string
    {
        return __('bo_texts');
    }

    /** Rows are kept in step with the texts by "Sync", never created by hand. */
    public static function canCreate(): bool
    {
        return false;
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Textarea::make('value')
                ->label(fn () => __('bo_custom_text'))
                ->helperText(fn (Translation $record) => __('bo_default_text') . ': ' . ($record->defaultValue() ?? '-'))
                ->rows(4)
                ->rules(static::placeholderRules()),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('locale')
                    ->label(fn () => __('bo_locale'))
                    ->badge()
                    ->sortable(),
                TextColumn::make('key')
                    ->label(fn () => __('bo_key'))
                    ->searchable()
                    ->sortable()
                    ->copyable()
                    ->wrap(),
                TextColumn::make('default')
                    ->label(fn () => __('bo_default_text'))
                    ->state(fn (Translation $record) => $record->defaultValue())
                    ->placeholder('-')
                    ->limit(70)
                    ->tooltip(fn (Translation $record) => $record->defaultValue())
                    ->wrap(),
                // Edit in place; blank goes back to the default text
                TextInputColumn::make('value')
                    ->label(fn () => __('bo_custom_text'))
                    ->searchable()
                    ->rules(static::placeholderRules()),
            ])
            ->defaultSort('key')
            ->paginated([25, 50, 100])
            ->defaultPaginationPageOption(50)
            ->filters([
                SelectFilter::make('locale')
                    ->label(fn () => __('bo_locale'))
                    ->options(fn () => Language::active()->pluck('native_name', 'code')->all()),
                Filter::make('customised')
                    ->label(fn () => __('bo_customised'))
                    ->query(fn (Builder $query) => $query->whereNotNull('value')->where('value', '!=', '')),
                // No text at all in this language: neither shipped nor typed here
                Filter::make('missing')
                    ->label(fn () => __('bo_missing'))
                    ->query(fn (Builder $query) => $query->where(fn (Builder $q) => $q->whereNull('value')->orWhere('value', ''))
                        ->whereIn('id', static::idsWithoutShippedText())),
            ])
            ->recordActions([
                EditAction::make(),
                Action::make('reset')
                    ->label(fn () => __('bo_reset_to_default'))
                    ->icon(Heroicon::OutlinedArrowPath)
                    ->color('gray')
                    ->requiresConfirmation()
                    ->visible(fn (Translation $record) => filled($record->value))
                    ->action(fn (Translation $record) => $record->update(['value' => null])),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListTranslations::route('/'),
        ];
    }

    /**
     * An edited text must keep the :placeholders the shipped one has
     * (e.g. ":seconds"), or the message would lose its numbers.
     *
     * @return Closure(Translation): array<int, Closure>
     */
    private static function placeholderRules(): Closure
    {
        return fn (Translation $record): array => [
            function (string $attribute, mixed $value, Closure $fail) use ($record) {
                if (blank($value)) {
                    return;
                }

                $missing = array_diff(
                    TranslationRepository::placeholders($record->defaultValue() ?? TranslationRepository::fileValue('en', $record->key)),
                    TranslationRepository::placeholders($value),
                );

                if ($missing !== []) {
                    $fail(__('bo_placeholder_error', ['placeholders' => implode(', ', $missing)]));
                }
            },
        ];
    }

    /** Ids of the rows whose language ships no text for the key (candidates for "missing"). */
    private static function idsWithoutShippedText(): array
    {
        return Translation::query()->get(['id', 'locale', 'key'])
            ->filter(fn (Translation $t) => blank(TranslationRepository::fileValue($t->locale, $t->key)))
            ->pluck('id')
            ->all();
    }
}
