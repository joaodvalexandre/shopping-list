<?php

namespace App\Filament\Resources\Pages;

use App\Filament\Resources\Pages\Pages\CreatePage;
use App\Filament\Resources\Pages\Pages\EditPage;
use App\Filament\Resources\Pages\Pages\ListPages;
use App\Models\Language;
use App\Models\Page;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\RichEditor;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Tabs;
use Filament\Schemas\Components\Tabs\Tab;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Table;

/** Content pages (about, privacy, help...) shown at /p/{slug}, one text per language. */
class PageResource extends Resource
{
    protected static ?string $model = Page::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedDocumentText;

    protected static ?int $navigationSort = 10;

    protected static ?string $recordTitleAttribute = 'slug';

    public static function getNavigationGroup(): ?string
    {
        return __('bo_group_content');
    }

    public static function getModelLabel(): string
    {
        return __('bo_page');
    }

    public static function getPluralModelLabel(): string
    {
        return __('bo_pages');
    }

    public static function form(Schema $schema): Schema
    {
        $default = Language::defaultCode();

        $tabs = Language::active()->map(fn (array $language) => Tab::make($language['native_name'])
            ->schema([
                // The default language must be filled in; the others fall back to it
                TextInput::make("title.{$language['code']}")
                    ->label(fn () => __('bo_title'))
                    ->required($language['code'] === $default)
                    ->maxLength(255),
                RichEditor::make("content.{$language['code']}")
                    ->label(fn () => __('bo_content'))
                    ->required($language['code'] === $default)
                    ->toolbarButtons([
                        ['bold', 'italic', 'underline', 'strike', 'link'],
                        ['h2', 'h3'],
                        ['bulletList', 'orderedList', 'blockquote'],
                        ['undo', 'redo'],
                    ]),
            ]))->all();

        return $schema->components([
            Section::make()->schema([
                TextInput::make('slug')
                    ->label(fn () => __('bo_slug'))
                    ->helperText(fn () => __('bo_slug_help'))
                    ->required()
                    ->maxLength(100)
                    ->regex('/^[a-z0-9]+(-[a-z0-9]+)*$/')
                    ->unique(ignoreRecord: true)
                    ->columnSpanFull(),
                Toggle::make('is_published')
                    ->label(fn () => __('bo_published')),
                Toggle::make('show_in_footer')
                    ->label(fn () => __('bo_in_footer'))
                    ->default(true),
            ])->columns(2),

            Tabs::make('languages')->tabs($tabs)->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('sort')->label('#')->sortable(),
                TextColumn::make('slug')
                    ->label(fn () => __('bo_slug'))
                    ->searchable()
                    ->sortable(),
                TextColumn::make('title')
                    ->label(fn () => __('bo_title'))
                    ->state(fn (Page $record) => $record->titleIn(Language::defaultCode())),
                ToggleColumn::make('is_published')->label(fn () => __('bo_published')),
                ToggleColumn::make('show_in_footer')->label(fn () => __('bo_in_footer')),
                TextColumn::make('updated_at')->label(fn () => __('bo_updated'))->since()->sortable(),
            ])
            ->defaultSort('sort')
            ->reorderable('sort')
            ->recordActions([
                Action::make('view')
                    ->label(fn () => __('bo_view_page'))
                    ->icon(Heroicon::OutlinedArrowRightStartOnRectangle)
                    ->url(fn (Page $record) => route('pages.show', $record->slug))
                    ->openUrlInNewTab()
                    ->visible(fn (Page $record) => $record->is_published),
                EditAction::make(),
                DeleteAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListPages::route('/'),
            'create' => CreatePage::route('/create'),
            'edit' => EditPage::route('/{record}/edit'),
        ];
    }
}
