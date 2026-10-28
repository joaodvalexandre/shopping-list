<?php

namespace App\Filament\Resources\Languages;

use App\Filament\Resources\Languages\Pages\CreateLanguage;
use App\Filament\Resources\Languages\Pages\EditLanguage;
use App\Filament\Resources\Languages\Pages\ListLanguages;
use App\Models\Language;
use BackedEnum;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Table;

/** The languages the web app is offered in. */
class LanguageResource extends Resource
{
    protected static ?string $model = Language::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedLanguage;

    protected static ?int $navigationSort = 20;

    protected static ?string $recordTitleAttribute = 'name';

    public static function getNavigationGroup(): ?string
    {
        return __('bo_group_content');
    }

    public static function getModelLabel(): string
    {
        return __('bo_language');
    }

    public static function getPluralModelLabel(): string
    {
        return __('bo_languages');
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('code')
                ->label(fn () => __('bo_code'))
                ->helperText(fn () => __('bo_code_help'))
                ->required()
                ->maxLength(10)
                ->regex('/^[a-z]{2,3}([_-][A-Za-z]{2,4})?$/')
                ->unique(ignoreRecord: true)
                // The code names the texts' file and rows, so it cannot change later
                ->disabledOn('edit'),
            TextInput::make('name')
                ->label(fn () => __('name'))
                ->required()
                ->maxLength(100),
            TextInput::make('native_name')
                ->label(fn () => __('bo_native_name'))
                ->required()
                ->maxLength(100),
            Select::make('flag')
                ->label(fn () => __('bo_flag'))
                ->options(fn () => static::flagOptions())
                ->searchable()
                ->helperText(fn () => __('bo_flag_help')),
            Toggle::make('is_active')
                ->label(fn () => __('bo_active'))
                ->default(true),
            Toggle::make('is_default')
                ->label(fn () => __('bo_default'))
                ->helperText(fn () => __('bo_default_help')),
            TextInput::make('sort')
                ->label(fn () => __('bo_sort'))
                ->numeric()
                ->default(0),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('flag')
                    ->label('')
                    ->html()
                    ->state(fn (Language $record) => Language::flagHtml($record->flag, $record->code)),
                TextColumn::make('name')->label(fn () => __('name'))->searchable()->sortable(),
                TextColumn::make('native_name')->label(fn () => __('bo_native_name'))->searchable(),
                TextColumn::make('code')->label(fn () => __('bo_code'))->badge()->sortable(),
                IconColumn::make('is_default')->label(fn () => __('bo_default'))->boolean(),
                // The default language must stay on
                ToggleColumn::make('is_active')
                    ->label(fn () => __('bo_active'))
                    ->disabled(fn (Language $record) => $record->is_default),
                TextColumn::make('sort')->label(fn () => __('bo_sort'))->sortable(),
            ])
            ->defaultSort('sort')
            ->recordActions([
                EditAction::make(),
                DeleteAction::make()
                    ->hidden(fn (Language $record) => $record->isProtected())
                    ->modalDescription(fn () => __('bo_delete_language_warning')),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListLanguages::route('/'),
            'create' => CreateLanguage::route('/create'),
            'edit' => EditLanguage::route('/{record}/edit'),
        ];
    }

    /**
     * The flag icons installed with the app (blade-flags): language flags and country flags.
     *
     * @return array<string, string>
     */
    private static function flagOptions(): array
    {
        $options = [];

        foreach (glob(base_path('vendor/outhebox/blade-flags/resources/svg/*.svg')) ?: [] as $path) {
            $name = pathinfo($path, PATHINFO_FILENAME);
            $options[$name] = $name;
        }

        ksort($options);

        return $options;
    }
}
