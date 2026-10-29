<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // The links of the site's navbar and footer, managed in the backoffice.
        // An item points at a content page, one of the app's own screens or any address; an item with children
        // is a dropdown (navbar) or a column heading (footer). Two levels at most.
        Schema::create('menu_items', function (Blueprint $table) {
            $table->id();
            $table->string('location');                         // "navbar", "user_menu" or "footer"
            $table->foreignId('parent_id')->nullable()->constrained('menu_items')->cascadeOnDelete();
            $table->foreignId('page_id')->nullable()->constrained('pages')->cascadeOnDelete();
            $table->string('screen')->nullable();               // one of the web app's own screens (see AppScreens)
            $table->string('url', 2048)->nullable();            // or any address
            $table->string('audience')->default('everyone');    // who is shown the link: everyone, guests, members, family_admins
            $table->json('label')->nullable();                  // {"en": "...", "pt": "..."}; empty: the page's title
            $table->boolean('new_tab')->default(false);
            $table->boolean('is_active')->default(true);
            $table->unsignedSmallInteger('sort')->default(0);
            $table->timestamps();

            $table->index(['location', 'parent_id', 'sort']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('menu_items');
    }
};
