<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;
use Illuminate\Auth\Authenticatable;
use Illuminate\Contracts\Auth\Authenticatable as AuthenticatableContract;
use Illuminate\Support\Facades\Storage;
use Tymon\JWTAuth\Contracts\JWTSubject;

class User extends Model implements AuthenticatableContract, JWTSubject
{
    use Authenticatable;

    protected $connection = 'mongodb';
    protected $collection = 'users';

    protected $fillable = [
        'name',
        'email',
        'password',
        'language',
        'theme',
        'image',
    ];

    protected $hidden = ['password'];

    protected $casts = ['email_verified_at' => 'datetime'];

    public function getJWTIdentifier()
    {
        return $this->getKey();
    }

    public function getJWTCustomClaims(): array
    {
        return [];
    }

    public function files()
    {
        return $this->hasMany(File::class, 'user_id', '_id');
    }

    public function getImageUrlAttribute(): string
    {
        return $this->image
            ? asset('storage/' . $this->image)
            : asset('images/default-avatar.png');
    }

    /**
     * When the image path changes, delete the old file from storage.
     */
    public function setImageAttribute($value): void
    {
        if ($this->image && $this->image !== $value) {
            Storage::disk('public')->delete($this->image);
        }

        $this->attributes['image'] = $value;
    }
}