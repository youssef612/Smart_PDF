<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class ConversationMessage extends Model
{
    protected $fillable = [
    'conversation_id',
    'role',
    'content',
    ];

    public function conversation()
    {
        return $this->belongsTo(Conversation::class);
    }
}
