<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A simple content page (about, privacy, help...) with a title and text per
 * language, written in the backoffice and shown at /p/{slug}.
 */
class Page extends Model
{
    protected $fillable = ['slug', 'title', 'content', 'is_published', 'sort'];

    protected function casts(): array
    {
        return [
            'title' => 'array',
            'content' => 'array',
            'is_published' => 'boolean',
        ];
    }

    public function scopePublished(Builder $query): Builder
    {
        return $query->where('is_published', true);
    }

    /** The title in $locale, else in the default language, else in any language that has one. */
    public function titleIn(?string $locale = null): string
    {
        return $this->translated($this->title ?? [], $locale) ?? $this->slug;
    }

    public function contentIn(?string $locale = null): string
    {
        return $this->translated($this->content ?? [], $locale) ?? '';
    }

    /** @param  array<string, ?string>  $texts */
    private function translated(array $texts, ?string $locale): ?string
    {
        $locale ??= app()->getLocale();

        foreach ([$locale, Language::defaultCode(), config('app.fallback_locale')] as $code) {
            if (filled($texts[$code] ?? null)) {
                return $texts[$code];
            }
        }

        return collect($texts)->first(fn ($text) => filled($text));
    }

    public function menuItems(): HasMany
    {
        return $this->hasMany(MenuItem::class);
    }
}
