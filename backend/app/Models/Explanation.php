<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class Explanation extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'explanations';

    protected $fillable = [
        'user_id',
        'file_id',
        'content',
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