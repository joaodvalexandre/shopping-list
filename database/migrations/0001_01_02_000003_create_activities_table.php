<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * What happened on a family's lists (an item added, put in the cart, bought, a list
     * created), who did it, and on which list. The phone app polls this to notify people
     * about what others did; each reader only gets the lists they may see.
     */
    public function up(): void
    {
        Schema::create('activities', function (Blueprint $table) {
            $table->id();
            $table->foreignId('family_id')->constrained()->cascadeOnDelete();
            $table->foreignId('shopping_list_id')->constrained()->cascadeOnDelete();
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('kind', 32);
            $table->string('subject')->nullable();      // the item name
            $table->unsignedInteger('quantity')->nullable();
            $table->timestamp('created_at', 3)->useCurrent();

            $table->index(['family_id', 'id']);
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('activities');
    }
};
