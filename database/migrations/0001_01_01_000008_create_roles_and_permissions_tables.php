<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // What the backoffice administrators may do. These are about the backoffice
        // only: a family's own roles and permissions live in `users` and `list_type_user`.
        Schema::create('roles', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();          // key, e.g. "content-editor"
            $table->string('description')->nullable();
            $table->boolean('is_system')->default(false); // shipped with the app: cannot be renamed or deleted
            $table->timestamps();
        });

        Schema::create('permissions', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();          // "<group>.<action>", e.g. "pages.update"
            $table->string('description')->nullable();
            $table->boolean('is_system')->default(false); // the code checks these: key cannot change
            $table->timestamps();
        });

        Schema::create('permission_role', function (Blueprint $table) {
            $table->foreignId('permission_id')->constrained()->cascadeOnDelete();
            $table->foreignId('role_id')->constrained()->cascadeOnDelete();
            $table->primary(['permission_id', 'role_id']);
        });

        Schema::create('admin_role', function (Blueprint $table) {
            $table->foreignId('admin_id')->constrained()->cascadeOnDelete();
            $table->foreignId('role_id')->constrained()->cascadeOnDelete();
            $table->primary(['admin_id', 'role_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_role');
        Schema::dropIfExists('permission_role');
        Schema::dropIfExists('permissions');
        Schema::dropIfExists('roles');
    }
};
