<?php

namespace App\Support\Translations;

use App\Models\Language;
use App\Models\Translation;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Cache;

/**
 * Reads the default texts shipped in resources/lang/*.json, the edits made in
 * the backoffice, and keeps the `translations` table in step with the keys.
 */
class TranslationRepository
{
    /** @var array<string, array<string, string>> per-request memo of the JSON files */
    private static array $files = [];

    public static function path(string $locale): string
    {
        return resource_path("lang/{$locale}.json");
    }

    /** @return array<string, string> */
    public static function fileLines(string $locale): array
    {
        if (! isset(self::$files[$locale])) {
            $path = self::path($locale);
            $decoded = is_file($path) ? json_decode((string) file_get_contents($path), true) : null;
            self::$files[$locale] = is_array($decoded) ? $decoded : [];
        }

        return self::$files[$locale];
    }

    public static function fileValue(string $locale, string $key): ?string
    {
        return self::fileLines($locale)[$key] ?? null;
    }

    /**
     * Edits made in the backoffice (blank ones ignored).
     *
     * @return array<string, string>
     */
    public static function overrides(string $locale): array
    {
        $cached = Cache::get("translations.{$locale}");

        if ($cached !== null) {
            return $cached;
        }

        try {
            $rows = Translation::where('locale', $locale)
                ->whereNotNull('value')->where('value', '!=', '')
                ->pluck('value', 'key')->all();
        } catch (QueryException) {
            return []; // table not there yet; do not cache
        }

        Cache::forever("translations.{$locale}", $rows);

        return $rows;
    }

    public static function flush(?string $locale = null): void
    {
        foreach ($locale ? [$locale] : Language::activeCodes() as $code) {
            Cache::forget("translations.{$code}");
        }

        // Laravel's translator also remembers what it already loaded in this process
        app('translator')->setLoaded([]);
    }

    /**
     * Every text key that ships with the app, in any language. Only these can be
     * overridden, so a stray row can never shadow a framework message
     * such as "validation.required".
     *
     * @return array<string, true>
     */
    public static function knownKeys(): array
    {
        $keys = [];

        foreach (glob(resource_path('lang/*.json')) ?: [] as $path) {
            foreach (array_keys(self::fileLines(pathinfo($path, PATHINFO_FILENAME))) as $key) {
                $keys[$key] = true;
            }
        }

        return $keys;
    }

    /** Forget the per-request file memo (tests, long-running workers). */
    public static function forgetFiles(): void
    {
        self::$files = [];
    }

    /**
     * Make sure every key of every shipped language exists as a row for every
     * active language, so each text can be edited (and missing ones spotted).
     * Never touches existing edits.
     *
     * @return int number of rows created
     */
    public static function sync(): int
    {
        self::forgetFiles();

        $locales = Language::activeCodes();
        $shippedLocales = collect(glob(resource_path('lang/*.json')) ?: [])
            ->map(fn (string $path) => pathinfo($path, PATHINFO_FILENAME));

        $keys = $shippedLocales
            ->flatMap(fn (string $locale) => array_keys(self::fileLines($locale)))
            ->unique()->sort()->values();

        $created = 0;

        foreach ($locales as $locale) {
            $existing = Translation::where('locale', $locale)->pluck('key')->flip();

            $missing = $keys->reject(fn (string $key) => $existing->has($key))
                ->map(fn (string $key) => ['locale' => $locale, 'key' => $key, 'created_at' => now(), 'updated_at' => now()])
                ->all();

            foreach (array_chunk($missing, 200) as $chunk) {
                Translation::insert($chunk);
            }

            $created += count($missing);
        }

        return $created;
    }

    /** Placeholders like :seconds that an edited text must keep. */
    public static function placeholders(?string $text): array
    {
        preg_match_all('/:[A-Za-z_]+/', (string) $text, $matches);

        return array_values(array_unique($matches[0]));
    }
}
