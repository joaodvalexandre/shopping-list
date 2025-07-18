<?php

namespace App\Http\Controllers;

use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Foundation\Validation\ValidatesRequests;
use Illuminate\Routing\Controller as BaseController;
use Illuminate\Support\Facades\File;

class Controller extends BaseController
{
    use AuthorizesRequests, ValidatesRequests;

    public function notificationToggle($message = '', $status = 'success'){
        session()->flash('notification', [
            'message' => $message,
            'type' => $status
        ]);
    }

    private function addTranslation(string $language, string $label, string $translation): void
    {
        $path = resource_path("lang/{$language}.json");

        if (!file_exists($path)) {
            file_put_contents($path, json_encode([], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
        }

        $translations = json_decode(file_get_contents($path), true) ?? [];

        $translations[$label] = $translation;

        file_put_contents($path, json_encode($translations, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
    }

    private function removeTranslation(string $label, ?string $language = null): void
    {
        $languages = $language
            ? [$language]
            : collect(File::files(resource_path('lang')))
                ->filter(fn ($file) => $file->getExtension() === 'json')
                ->map(fn ($file) => $file->getFilenameWithoutExtension())
                ->all();

        foreach ($languages as $lang) {
            $path = resource_path("lang/{$lang}.json");

            if (!file_exists($path)) continue;

            $translations = json_decode(file_get_contents($path), true) ?? [];

            if (array_key_exists($label, $translations)) {
                unset($translations[$label]);
                file_put_contents($path, json_encode($translations, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
            }
        }
    }

}
