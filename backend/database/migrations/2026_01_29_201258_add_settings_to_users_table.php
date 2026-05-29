<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adds language and theme preference columns used by the User model.
 * These were missing from all previous migrations, causing runtime errors
 * whenever $user->language or $user->theme was accessed.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('language')->default('ar');
            $table->string('theme')->default('light');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['language', 'theme']);
        });
    }
};