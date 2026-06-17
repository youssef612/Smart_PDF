<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class ExamSheet extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'exam_sheets';

    protected $fillable = [
        'user_id',
        'title',
        'subject',
        'file_id',
        'file_name',
        'questions',
        'pinned',
        'page_count',       // ← أضف هذا
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'questions'  => 'array',
        'pinned'     => 'boolean',
        'page_count' => 'integer', // ← أضف هذا
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id', '_id');
    }

    public function file()
    {
        return $this->belongsTo(File::class, 'file_id', '_id');
    }
}