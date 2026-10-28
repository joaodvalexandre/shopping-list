<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shopping_lists', function (Blueprint $table) {
            $table->id();
            // Stable identity shared by the web app, every phone and the sync API
            $table->uuid('uuid')->unique();
            $table->string('name');
            // When each synced field last changed (ms precision) - last write wins per field
            $table->timestamp('name_changed_at', 3)->useCurrent();
            $table->foreignId('family_id')->constrained()->cascadeOnDelete();
            // A type that still has lists cannot be deleted
            $table->foreignId('list_type_id')->constrained()->restrictOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps(3);
            // Deleted rows stay as tombstones so devices learn about deletions
            $table->softDeletes('deleted_at', 3);

            $table->index(['family_id', 'updated_at']);
        });

        // Users who must not see a list at all (e.g. the birthday person)
        Schema::create('shopping_list_hidden_from', function (Blueprint $table) {
            $table->foreignId('shopping_list_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();

            $table->primary(['shopping_list_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shopping_list_hidden_from');
        Schema::dropIfExists('shopping_lists');
    }
};
