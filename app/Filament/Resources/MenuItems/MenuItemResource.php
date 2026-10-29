<?php

namespace App\Filament\Resources\MenuItems;

use App\Filament\Resources\MenuItems\Pages\CreateMenuItem;
use App\Filament\Resources\MenuItems\Pages\EditMenuItem;
use App\Filament\Resources\MenuItems\Pages\ListMenuItems;
use App\Models\Language;
use App\Models\MenuItem;
use App\Models\Page;
use App\Support\Menus\AppScreens;
use BackedEnum;
use Closure;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Tabs;
use Filament\Schemas\Components\Tabs\Tab;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Components\Utilities\Set;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Every link of the web app's navbar, account menu and footer. A link points
 * at a content page, one of the app's own screens (dashboard, lists, family,
 * settings...) or an address; it is shown to everyone, guests, signed-in
 * members or family admins; and one with others under it becomes a dropdown
 * (navbar, account menu) or a column (footer).
 */
class MenuItemResource extends Resource
{
    protected static ?string $model = MenuItem::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedBars3BottomLeft;

    protected static ?int $navigationSort = 11;

    public static function getNavigationGroup(): ?string
    {
        return __('bo_group_content');
    }

    public static function getModelLabel(): string
    {
        return __('bo_menu_item');
    }

    public static function getPluralModelLabel(): string
    {
        return __('bo_menus');
    }

    public static function getRecordTitle(?Model $record): ?string
    {
        return $record instanceof MenuItem ? $record->labelIn(Language::defaultCode()) : null;
    }

    /** @return array<string, string> */
    public static function locations(): array
    {
        return [
            MenuItem::NAVBAR => __('bo_navbar'),
            MenuItem::USER_MENU => __('bo_user_menu'),
            MenuItem::FOOTER => __('bo_footer'),
        ];
    }

    /** @return array<string, string> */
    private static function audienceOptions(?string $screen = null): array
    {
        return collect(AppScreens::audiencesFor($screen))
            ->mapWithKeys(fn (string $audience) => [$audience => __("bo_audience_{$audience}")])
            ->all();
    }

    /** What the link points at, as the form's choice. */
    private static function targets(): array
    {
        return [
            'page' => __('bo_menu_kind_page'),
            'screen' => __('bo_menu_kind_screen'),
            'link' => __('bo_menu_kind_link'),
            'heading' => __('bo_menu_kind_heading'),
        ];
    }

    /**
     * The form's "points at" choice decides which of page, screen and address is
     * kept; the others are cleared, so switching never leaves a stale target behind.
     *
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    public static function normalise(array $data): array
    {
        $target = $data['target'] ?? null;
        unset($data['target']);

        foreach (['page' => 'page_id', 'screen' => 'screen', 'link' => 'url'] as $kind => $column) {
            if ($target !== null && $target !== $kind) {
                $data[$column] = null;
            }
        }

        if ($target === 'heading') {
            $data['page_id'] = $data['screen'] = $data['url'] = null;
        }

        return $data;
    }

    public static function form(Schema $schema): Schema
    {
        $default = Language::defaultCode();

        $tabs = Language::active()->map(fn (array $language) => Tab::make($language['native_name'])
            ->schema([
                TextInput::make("label.{$language['code']}")
                    ->label(fn () => __('bo_menu_label'))
                    ->maxLength(100)
                    // A page or a screen brings its own name; a link or a heading needs one
                    ->required(fn (Get $get) => $language['code'] === $default && in_array($get('target'), ['link', 'heading'], true)),
            ]))->all();

        return $schema->components([
            Section::make()->columns(2)->schema([
                Select::make('location')
                    ->label(fn () => __('bo_menu_location'))
                    ->helperText(fn () => __('bo_menu_location_help'))
                    ->options(static::locations())
                    ->default(MenuItem::FOOTER)
                    ->required()
                    ->native(false)
                    ->live()
                    ->afterStateUpdated(fn (Set $set) => $set('parent_id', null)),

                // Two levels at most: only top-level items can hold others
                Select::make('parent_id')
                    ->label(fn () => __('bo_menu_parent'))
                    ->helperText(fn () => __('bo_menu_parent_help'))
                    ->options(fn (Get $get, ?MenuItem $record) => MenuItem::query()
                        ->where('location', $get('location'))
                        ->whereNull('parent_id')
                        ->when($record, fn (Builder $query) => $query->whereKeyNot($record->getKey()))
                        ->orderBy('sort')->orderBy('id')
                        ->get()
                        ->mapWithKeys(fn (MenuItem $item) => [$item->id => $item->labelIn(Language::defaultCode())])
                        ->all())
                    ->placeholder(fn () => __('bo_menu_top_level'))
                    ->native(false)
                    // An item that already holds others cannot go under one
                    ->disabled(fn (?MenuItem $record) => $record?->children()->exists())
                    ->dehydrated(),
            ]),

            Section::make()->columns(2)->schema([
                Select::make('target')
                    ->label(fn () => __('bo_menu_points_at'))
                    ->options(static::targets())
                    ->default('page')
                    ->required()
                    ->native(false)
                    ->live()
                    ->afterStateHydrated(fn (Select $component, ?MenuItem $record) => $component->state($record?->kind() ?? 'page'))
                    ->afterStateUpdated(fn (Set $set, Get $get) => $set('audience', array_key_first(static::audienceOptions($get('screen'))))),

                Select::make('page_id')
                    ->label(fn () => __('bo_menu_page'))
                    ->options(fn () => Page::orderBy('slug')->get()
                        ->mapWithKeys(fn (Page $page) => [$page->id => $page->titleIn(Language::defaultCode()) . ' (/p/' . $page->slug . ')'])
                        ->all())
                    ->searchable()
                    ->native(false)
                    ->required(fn (Get $get) => $get('target') === 'page')
                    ->visible(fn (Get $get) => $get('target') === 'page'),

                Select::make('screen')
                    ->label(fn () => __('bo_menu_screen'))
                    ->helperText(fn () => __('bo_menu_screen_help'))
                    ->options(collect(AppScreens::all())->map(fn (array $screen) => __($screen['label']))->all())
                    ->native(false)
                    ->live()
                    ->required(fn (Get $get) => $get('target') === 'screen')
                    ->visible(fn (Get $get) => $get('target') === 'screen')
                    ->afterStateUpdated(fn (Set $set, Get $get) => $set('audience', array_key_first(static::audienceOptions($get('screen'))))),

                TextInput::make('url')
                    ->label(fn () => __('bo_menu_url'))
                    ->helperText(fn () => __('bo_menu_url_help'))
                    ->maxLength(2048)
                    ->required(fn (Get $get) => $get('target') === 'link')
                    ->visible(fn (Get $get) => $get('target') === 'link')
                    ->rule(fn () => function (string $attribute, $value, Closure $fail) {
                        if (filled($value) && MenuItem::safeUrl($value) === null) {
                            $fail(__('bo_menu_url_invalid'));
                        }
                    }),

                // Who is shown the link (a screen only offers the audiences it is meant for)
                Select::make('audience')
                    ->label(fn () => __('bo_menu_audience'))
                    ->helperText(fn () => __('bo_menu_audience_help'))
                    ->options(fn (Get $get) => static::audienceOptions($get('target') === 'screen' ? $get('screen') : null))
                    ->default(AppScreens::EVERYONE)
                    ->required()
                    ->native(false),
            ]),

            Section::make(fn () => __('bo_menu_label'))
                ->description(fn () => __('bo_menu_label_help'))
                ->schema([Tabs::make('languages')->tabs($tabs)]),

            Section::make()->columns(2)->schema([
                Toggle::make('new_tab')->label(fn () => __('bo_new_tab')),
                Toggle::make('is_active')->label(fn () => __('bo_active'))->default(true),
            ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn (Builder $query) => $query->with(['page', 'parent']))
            ->columns([
                TextColumn::make('label')
                    ->label(fn () => __('bo_menu_label'))
                    ->state(fn (MenuItem $record) => ($record->parent_id ? '↳ ' : '') . $record->labelIn(Language::defaultCode()))
                    ->weight(fn (MenuItem $record) => $record->parent_id ? null : 'medium')
                    ->description(fn (MenuItem $record) => match ($record->kind()) {
                        'page' => '/p/' . $record->page?->slug,
                        'screen' => parse_url((string) $record->href(), PHP_URL_PATH),
                        default => $record->url,
                    }),
                TextColumn::make('location')
                    ->label(fn () => __('bo_menu_location'))
                    ->formatStateUsing(fn (string $state) => static::locations()[$state] ?? $state)
                    ->badge()
                    ->color(fn (string $state) => match ($state) {
                        MenuItem::NAVBAR => 'primary',
                        MenuItem::USER_MENU => 'info',
                        default => 'gray',
                    }),
                TextColumn::make('kind')
                    ->label(fn () => __('bo_menu_kind'))
                    ->state(fn (MenuItem $record) => __('bo_menu_kind_' . $record->kind()))
                    ->badge()
                    ->color('gray'),
                TextColumn::make('audience')
                    ->label(fn () => __('bo_menu_audience'))
                    ->formatStateUsing(fn (string $state) => __("bo_audience_{$state}"))
                    ->badge()
                    ->color(fn (string $state) => $state === AppScreens::EVERYONE ? 'success' : 'warning'),
                ToggleColumn::make('is_active')->label(fn () => __('bo_active')),
            ])
            ->defaultSort(fn (Builder $query) => $query->orderBy('location')->orderBy('sort')->orderBy('id'))
            ->reorderable('sort')
            ->filters([
                SelectFilter::make('location')
                    ->label(fn () => __('bo_menu_location'))
                    ->options(static::locations()),
                SelectFilter::make('audience')
                    ->label(fn () => __('bo_menu_audience'))
                    ->options(static::audienceOptions()),
            ])
            ->recordActions([
                EditAction::make(),
                DeleteAction::make()->modalDescription(fn () => __('bo_menu_delete_warning')),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListMenuItems::route('/'),
            'create' => CreateMenuItem::route('/create'),
            'edit' => EditMenuItem::route('/{record}/edit'),
        ];
    }
}
