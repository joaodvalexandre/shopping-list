<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('items', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->unsignedBigInteger('shopping_list_id'); // Reference to shopping_lists
            $table->string('name');                         // Free-form item name
            $table->integer('quantity')->default(1);        // Quantity for this item
            $table->unsignedBigInteger('status_id')->nullable(); // Status of the item

            // When each synced field last changed (ms precision) - last write wins per field
            $table->timestamp('name_changed_at', 3)->useCurrent();
            $table->timestamp('quantity_changed_at', 3)->useCurrent();
            $table->timestamp('status_changed_at', 3)->useCurrent();

            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            // Foreign keys
            $table->foreign('shopping_list_id')->references('id')->on('shopping_lists')->onDelete('cascade');
            $table->foreign('status_id')->references('id')->on('status')->onDelete('set null');

            $table->index(['shopping_list_id', 'updated_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('items');
    }
};
