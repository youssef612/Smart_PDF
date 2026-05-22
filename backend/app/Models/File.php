<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class File extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'files';

    protected $fillable = [
        'user_id',
        'file_name',
        'file_type',
        'file_path',
        'file_hash',  // ✅ أضفها هنا
        'size',
        'status',
        'pages',
        'extracted_text',
        'uploaded_at',
        'page_count',
    ];

    protected $casts = [
        'size'        => 'integer',
        'uploaded_at' => 'datetime',
        'pages'       => 'array',    // ✅ مهم جداً لتحويلها تلقائياً لمصفوفة PHP
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id', '_id');
    }

    public function summaries()
    {
        return $this->hasMany(Summary::class, 'file_id', '_id');
    }

    public function questions()
    {
        return $this->hasMany(Question::class, 'file_id', '_id');
    }

    public function explanations()
    {
        return $this->hasMany(Explanation::class, 'file_id', '_id');
    }
}