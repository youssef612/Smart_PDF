<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class Question extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'questions';

    protected $fillable = [
        'user_id',
        'file_id',
        'question',
        'type',
        'difficulty',
        'count',
    ];

    protected $casts = [
        'count' => 'integer',
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