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
            $table->string('name');
            $table->integer('quantity')->default(1);
            $table->unsignedBigInteger('status_id')->nullable();
            $table->timestamps();

            $table->foreign('status_id')->references('id')->on('status')->onDelete('set null');
        });
    }

    public function down()
    {
        Schema::dropIfExists('shopping_lists');
    }
};
