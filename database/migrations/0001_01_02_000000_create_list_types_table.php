<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Each family defines its own list types (groceries, party, ...)
        Schema::create('list_types', function (Blueprint $table) {
            $table->id();
            $table->foreignId('family_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->timestamps();

            $table->unique(['family_id', 'name']);
        });

        // What each member may do with the lists of a given type.
        // Admins ignore this table: they can do everything in their family.
        Schema::create('list_type_user', function (Blueprint $table) {
            $table->id();
            $table->foreignId('list_type_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->boolean('can_view')->default(false);
            $table->boolean('can_add_items')->default(false);
            $table->boolean('can_edit_items')->default(false);
            $table->boolean('can_change_status')->default(false);
            $table->boolean('can_manage_lists')->default(false);
            $table->timestamps();

            $table->unique(['list_type_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('list_type_user');
        Schema::dropIfExists('list_types');
    }
};
