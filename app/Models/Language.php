<?php

namespace App\Models;

use App\Support\Translations\TranslationRepository;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\QueryException;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;

/**
 * A language the web app is offered in, managed from the backoffice.
 * Texts live in resources/lang/{code}.json (defaults) and in the
 * `translations` table (edits made in the backoffice).
 */
class Language extends Model
{
    /** Used until the table exists/has rows (fresh clone, tests, mid-migration). */
    public const FALLBACK_CODES = ['pt', 'en'];

    private const CACHE_KEY = 'languages.active';

    protected $fillable = ['code', 'name', 'native_name', 'flag', 'is_active', 'is_default', 'sort'];

    protected function casts(): array
    {
        return ['is_active' => 'boolean', 'is_default' => 'boolean'];
    }

    protected static function booted(): void
    {
        // The default language must always be on offer
        static::saving(function (Language $language) {
            if ($language->is_default) {
                $language->is_active = true;
            }
        });

        // ...and neither it nor the fallback language (which supplies any missing text) can go
        static::deleting(fn (Language $language) => ! $language->isProtected());

        static::saved(function (Language $language) {
            // Exactly one default language
            if ($language->is_default) {
                static::where('id', '!=', $language->id)->where('is_default', true)->update(['is_default' => false]);
            }
            static::flush();
        });

        // A new language gets one (empty) editable row per text
        // ("created" fires before "saved", so refresh the language list first)
        static::created(function () {
            static::flush();
            TranslationRepository::sync();
        });

        static::deleted(function (Language $language) {
            Translation::where('locale', $language->code)->delete();
            static::flush();
        });
    }

    /** The default language and the fallback language cannot be deleted. */
    public function isProtected(): bool
    {
        return $this->is_default || $this->code === config('app.fallback_locale');
    }

    /** @return Collection<int, array{code: string, name: string, native_name: string, flag: ?string, is_default: bool}> */
    public static function active(): Collection
    {
        $rows = Cache::get(self::CACHE_KEY);

        if ($rows === null) {
            try {
                $rows = static::where('is_active', true)->orderBy('sort')->orderBy('name')->get()
                    ->map(fn (Language $l) => $l->only(['code', 'name', 'native_name', 'flag', 'is_default']))
                    ->all();
            } catch (QueryException) {
                return collect(); // table not there yet; do not cache
            }

            Cache::forever(self::CACHE_KEY, $rows);
        }

        return collect($rows);
    }

    /** @return list<string> */
    public static function activeCodes(): array
    {
        $codes = static::active()->pluck('code')->all();

        return $codes !== [] ? $codes : self::FALLBACK_CODES;
    }

    public static function defaultCode(): string
    {
        $default = static::active()->firstWhere('is_default', true)['code'] ?? null;

        return $default ?? static::activeCodes()[0];
    }

    public static function isActive(?string $code): bool
    {
        return $code !== null && in_array($code, static::activeCodes(), true);
    }

    public static function flush(): void
    {
        Cache::forget(self::CACHE_KEY);
    }

    /** A flag as inline SVG, or the language code as a small badge when there is no icon. */
    public static function flagHtml(?string $flag, string $code, string $class = 'w-6 h-6'): string
    {
        if ($flag) {
            try {
                return svg('flag-' . $flag, $class)->toHtml();
            } catch (\Throwable) {
                // unknown icon: fall through to the badge
            }
        }

        return '<span class="inline-flex items-center justify-center rounded bg-gray-200 px-1 text-xs font-semibold uppercase text-gray-700 dark:bg-gray-600 dark:text-gray-100">'
            . e($code) . '</span>';
    }
}
