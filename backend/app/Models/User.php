<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/**
 * @property string $id
 * @property string $username
 * @property string $display_name
 * @property string $password_hash
 * @property bool $must_change_password
 * @property bool $active
 *
 * @method static \Illuminate\Database\Eloquent\Builder<static> whereRaw(string $sql, array $bindings = [])
 */
class User extends Authenticatable
{
    use HasApiTokens, HasFactory, HasUuids, Notifiable;

    protected $fillable = [
        'id',
        'username',
        'display_name',
        'password_hash',
        'must_change_password',
        'active',
    ];

    protected $hidden = [
        'password_hash',
    ];

    protected function casts(): array
    {
        return [
            'must_change_password' => 'boolean',
            'active' => 'boolean',
        ];
    }

    public function getAuthPassword(): string
    {
        return $this->password_hash;
    }
}
