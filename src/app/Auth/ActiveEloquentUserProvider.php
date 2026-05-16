<?php

namespace App\Auth;

use Closure;
use Illuminate\Auth\EloquentUserProvider;
use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Contracts\Support\Arrayable;
use Illuminate\Support\Str;

class ActiveEloquentUserProvider extends EloquentUserProvider
{
    public function retrieveByCredentials(array $credentials): ?Authenticatable
    {
        $credentials = array_filter(
            $credentials,
            fn ($key) => ! str_contains($key, 'password'),
            ARRAY_FILTER_USE_KEY
        );

        if (empty($credentials)) {
            return null;
        }

        $query = $this->newModelQuery();

        foreach ($credentials as $key => $value) {
            if (is_array($value) || $value instanceof Arrayable) {
                $query->whereIn($key, $value);
            } elseif ($value instanceof Closure) {
                $value($query);
            } elseif (Str::contains($key, '->')) {
                $query->where($key, $value);
            } else {
                $query->where($key, $value);
            }
        }

        return $query->where('is_active', true)->first();
    }

    public function retrieveById($identifier): ?Authenticatable
    {
        $model = $this->createModel();

        return $this->newModelQuery()
            ->where($model->getAuthIdentifierName(), $identifier)
            ->where('is_active', true)
            ->first();
    }

    public function retrieveByToken($identifier, #[\SensitiveParameter] $token): ?Authenticatable
    {
        $user = parent::retrieveByToken($identifier, $token);

        if ($user !== null && ($user->is_active ?? true) === false) {
            return null;
        }

        return $user;
    }
}
