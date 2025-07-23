<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('status', function (Blueprint $table) {
            $table->id(); // Auto-incrementing primary key
            $table->string('status', 100)->unique(); // Unique for distinct status names
            $table->string('code', 100)->unique(); // Unique for distinct status names
            $table->string('color', 7)->default('#000000'); // HEX color with default
            $table->timestamps(); // Created_at and updated_at timestamps
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('status');
    }
};
