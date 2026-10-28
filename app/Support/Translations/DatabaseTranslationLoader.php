<?php

namespace App\Support\Translations;

use Illuminate\Contracts\Translation\Loader;

/**
 * Wraps Laravel's file loader: the app's JSON texts come from the files as
 * usual, then the edits made in the backoffice are laid over them.
 */
class DatabaseTranslationLoader implements Loader
{
    public function __construct(private Loader $files)
    {
    }

    public function load($locale, $group, $namespace = null)
    {
        $lines = $this->files->load($locale, $group, $namespace);

        // JSON texts are the "*" group of the "*" namespace
        if ($group === '*' && $namespace === '*') {
            return array_merge($lines, array_intersect_key(
                TranslationRepository::overrides($locale),
                TranslationRepository::knownKeys(),
            ));
        }

        return $lines;
    }

    public function addNamespace($namespace, $hint)
    {
        $this->files->addNamespace($namespace, $hint);
    }

    public function addJsonPath($path)
    {
        $this->files->addJsonPath($path);
    }

    public function namespaces()
    {
        return $this->files->namespaces();
    }
}
