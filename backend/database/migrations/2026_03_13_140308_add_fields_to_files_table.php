<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * NOTE: size, status, and uploaded_at were moved into the initial
 * create_files_table migration (2026_02_13_152822) to keep the schema
 * definition in one place and avoid ALTER TABLE races.
 * This migration is intentionally a no-op and kept only for history.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Fields already included in create_files_table migration.
    }

    public function down(): void
    {
        // Nothing to reverse.
    }
};