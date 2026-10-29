<?php

namespace App\Models;

use App\Support\Menus\AppScreens;
use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\QueryException;
use Illuminate\Support\Collection;

/**
 * One link of the navbar, the account menu or the footer. It points at a
 * content page, one of the app's own screens or an address; with children it
 * becomes a dropdown (navbar) or a column (footer). The audience decides who is
 * shown it: everyone, guests, signed-in members or family admins.
 */
class MenuItem extends Model
{
    public const NAVBAR = 'navbar';

    public const USER_MENU = 'user_menu';

    public const FOOTER = 'footer';

    protected $fillable = ['location', 'parent_id', 'page_id', 'screen', 'url', 'audience', 'label', 'new_tab', 'is_active', 'sort'];

    protected function casts(): array
    {
        return [
            'label' => 'array',
            'new_tab' => 'boolean',
            'is_active' => 'boolean',
        ];
    }

    /** @return list<string> */
    public static function locations(): array
    {
        return [self::NAVBAR, self::USER_MENU, self::FOOTER];
    }

    protected static function booted(): void
    {
        static::saving(function (MenuItem $item) {
            // An item lives where its parent lives
            if ($item->parent_id) {
                $item->location = static::whereKey($item->parent_id)->value('location') ?? $item->location;
            }

            // It points at one thing only: a page, a screen or an address
            if ($item->page_id) {
                $item->screen = null;
                $item->url = null;
            } elseif ($item->screen) {
                $item->url = null;
            }

            // A screen is only for the people it is meant for (the dashboard is not for guests)
            if ($item->screen && ! in_array($item->audience, AppScreens::audiencesFor($item->screen), true)) {
                $item->audience = AppScreens::audiencesFor($item->screen)[0];
            }
        });

        static::saved(function (MenuItem $item) {
            if ($item->wasChanged('location')) {
                $item->children()->update(['location' => $item->location]);
            }
        });
    }

    public function parent(): BelongsTo
    {
        return $this->belongsTo(self::class, 'parent_id');
    }

    public function children(): HasMany
    {
        return $this->hasMany(self::class, 'parent_id')->orderBy('sort')->orderBy('id');
    }

    public function page(): BelongsTo
    {
        return $this->belongsTo(Page::class);
    }

    public function scopeAt(Builder $query, string $location): Builder
    {
        return $query->where('location', $location);
    }

    /** What the link points at: "page", "screen", "link", or "heading" (nothing: it only holds others). */
    public function kind(): string
    {
        return match (true) {
            filled($this->page_id) => 'page',
            filled($this->screen) => 'screen',
            filled($this->url) => 'link',
            default => 'heading',
        };
    }

    /** The label in $locale, else the default language, else the page's title or the screen's name, else the address. */
    public function labelIn(?string $locale = null): string
    {
        $locale ??= app()->getLocale();
        $labels = $this->label ?? [];

        foreach ([$locale, Language::defaultCode(), config('app.fallback_locale')] as $code) {
            if (filled($labels[$code] ?? null)) {
                return $labels[$code];
            }
        }

        if ($this->page) {
            return $this->page->titleIn($locale);
        }

        if ($screen = AppScreens::find($this->screen)) {
            return __($screen['label'], [], $locale);
        }

        return (string) (collect($labels)->first(fn ($text) => filled($text)) ?? $this->url);
    }

    /**
     * Where the link goes, or null when it goes nowhere (a column heading, an
     * unpublished page, a screen that no longer exists, or an address that is
     * not http(s) or a path on this site).
     */
    public function href(): ?string
    {
        if ($this->page_id) {
            return $this->page?->is_published ? route('pages.show', $this->page->slug) : null;
        }

        if ($this->screen) {
            return AppScreens::url($this->screen);
        }

        return static::safeUrl($this->url);
    }

    /** Is this the page being shown right now? (For the highlighted link in the navbar.) */
    public function isCurrent(): bool
    {
        if ($this->page_id) {
            return $this->page && request()->is('p/' . $this->page->slug);
        }

        $patterns = AppScreens::find($this->screen)['active'] ?? [];

        return $patterns !== [] && request()->routeIs($patterns);
    }

    /** Only http(s) addresses and paths of this site: never "javascript:" and the like. */
    public static function safeUrl(?string $url): ?string
    {
        $url = trim((string) $url);

        if ($url === '') {
            return null;
        }

        if (str_starts_with($url, '/') && ! str_starts_with($url, '//')) {
            return url($url);
        }

        return preg_match('#^https?://[^\s]+$#i', $url) === 1 ? $url : null;
    }

    /** Is this link meant for the person looking ($user null: a guest)? */
    public function isFor(?Authenticatable $user): bool
    {
        return match ($this->audience) {
            AppScreens::GUESTS => $user === null,
            AppScreens::MEMBERS => $user !== null,
            AppScreens::FAMILY_ADMINS => $user instanceof User && $user->isFamilyAdmin(),
            default => true,
        };
    }

    /**
     * The active items of a location that $user may be shown, as a tree two
     * levels deep. A link to an unpublished page, or a heading with nothing
     * under it, is left out. Empty (never an error) when the table does not exist yet.
     *
     * @return Collection<int, MenuItem>
     */
    public static function tree(string $location, ?Authenticatable $user = null): Collection
    {
        try {
            $items = static::at($location)
                ->where('is_active', true)
                ->with('page')
                ->orderBy('sort')
                ->orderBy('id')
                ->get()
                ->filter(fn (MenuItem $item) => $item->isFor($user));
        } catch (QueryException) {
            return collect();
        }

        $children = $items->whereNotNull('parent_id')->groupBy('parent_id');

        return $items->whereNull('parent_id')
            ->each(fn (MenuItem $item) => $item->setRelation('children', ($children[$item->id] ?? collect())
                ->filter(fn (MenuItem $child) => $child->href() !== null)
                ->values()))
            ->filter(fn (MenuItem $item) => $item->href() !== null || $item->children->isNotEmpty())
            ->values();
    }

    /**
     * What the navbar shows to someone signed in: what was arranged in the
     * backoffice, but never nothing, so nobody is left without a way around.
     *
     * @return Collection<int, MenuItem>
     */
    public static function navbarFor(?Authenticatable $user): Collection
    {
        $items = static::tree(self::NAVBAR, $user);

        if ($items->isNotEmpty() || $user === null) {
            return $items;
        }

        return collect(['dashboard', 'shopping_lists'])
            ->map(fn (string $screen) => new static(['location' => self::NAVBAR, 'screen' => $screen, 'audience' => AppScreens::MEMBERS]))
            ->each(fn (MenuItem $item) => $item->setRelation('children', collect()));
    }
}
