<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * NOTE: user_id is already nullable in the updated create_files_table
 * migration. This migration is kept for history but is a no-op.
 * If you are running this on a pre-existing database that still has
 * the old non-nullable user_id, uncomment the body below.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Already nullable in create_files_table.
        // Uncomment if applying to an existing DB with old schema:
        //
        // Schema::table('files', function (Blueprint $table) {
        //     $table->unsignedBigInteger('user_id')->nullable()->change();
        // });
    }

    public function down(): void
    {
        // Schema::table('files', function (Blueprint $table) {
        //     $table->unsignedBigInteger('user_id')->nullable(false)->change();
        // });
    }
};