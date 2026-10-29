<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\Mobile\MobileContent;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Languages, texts, content pages and menu links, for the phone to keep in its own
 * database. Public (the sign-in screen needs them too). The app passes the version
 * it already holds and is told so when there is nothing new.
 */
class ContentController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $content = MobileContent::build();

        if ($request->query('version') === $content['version']) {
            return response()->json(['version' => $content['version'], 'unchanged' => true]);
        }

        return response()->json($content);
    }
}
