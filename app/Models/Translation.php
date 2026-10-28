<?php

namespace App\Models;

use App\Support\Translations\TranslationRepository;
use Illuminate\Database\Eloquent\Model;

/**
 * One text in one language, edited in the backoffice. An empty value means
 * "use the default from resources/lang/{locale}.json".
 */
class Translation extends Model
{
    protected $fillable = ['locale', 'key', 'value'];

    protected static function booted(): void
    {
        static::saved(fn (Translation $t) => TranslationRepository::flush($t->locale));
        static::deleted(fn (Translation $t) => TranslationRepository::flush($t->locale));
    }

    /** The text that ships with the app for this language. */
    public function defaultValue(): ?string
    {
        return TranslationRepository::fileValue($this->locale, $this->key);
    }
}
