<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('items', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('shopping_list_id'); // Reference to shopping_lists
            $table->string('name');                    // Free-form item name
            $table->integer('quantity')->default(1);        // Quantity for this item
            $table->unsignedBigInteger('status_id')->nullable(); // Status of the item

            $table->timestamps();

            // Foreign keys
            $table->foreign('shopping_list_id')->references('id')->on('shopping_lists')->onDelete('cascade');
            $table->foreign('status_id')->references('id')->on('status')->onDelete('set null');

            // Optional index for performance
            $table->index('shopping_list_id');
        });
    }

    public function down()
    {
        Schema::dropIfExists('items');
    }
};
