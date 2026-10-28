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
            $table->unsignedBigInteger('family_id'); // ID of associated family
            $table->timestamps();

            $table->foreign('family_id')->references('id')->on('families')->onDelete('cascade');
        });
    }

    public function down()
    {
        Schema::dropIfExists('shopping_lists');
    }
};
