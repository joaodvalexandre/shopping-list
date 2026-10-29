<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Languages the web app is offered in
        Schema::create('languages', function (Blueprint $table) {
            $table->id();
            $table->string('code', 10)->unique();       // en, pt, es, pt-BR ...
            $table->string('name');                     // English name: Portuguese
            $table->string('native_name');              // Português
            $table->string('flag')->nullable();         // blade-flags icon, e.g. language-pt
            $table->boolean('is_active')->default(true);
            $table->boolean('is_default')->default(false);
            $table->unsignedSmallInteger('sort')->default(0);
            $table->timestamps();
        });

        // Editable texts. resources/lang/*.json provide the defaults; a row here
        // overrides one text in one language. An empty value means "use the default".
        Schema::create('translations', function (Blueprint $table) {
            $table->id();
            $table->string('locale', 10);
            $table->string('key', 191);
            $table->text('value')->nullable();
            $table->timestamps();

            $table->unique(['locale', 'key']);
        });

        // Simple content pages (about, privacy, help...) with a text per language
        Schema::create('pages', function (Blueprint $table) {
            $table->id();
            $table->string('slug')->unique();
            $table->json('title');                      // {"en": "...", "pt": "..."}
            $table->json('content');
            $table->boolean('is_published')->default(false);
            $table->unsignedSmallInteger('sort')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pages');
        Schema::dropIfExists('translations');
        Schema::dropIfExists('languages');
    }
};
