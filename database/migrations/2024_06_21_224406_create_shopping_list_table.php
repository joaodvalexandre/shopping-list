<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('shopping_lists', function (Blueprint $table) {
            $table->id();
            $table->string('name'); // Name of the shopping list
            $table->unsignedBigInteger('status_id')->nullable(); // Overall status (e.g., pending, completed)
            $table->timestamps();

            $table->foreign('status_id')->references('id')->on('status')->onDelete('set null');
        });
    }

    public function down()
    {
        Schema::dropIfExists('shopping_lists');
    }
};
