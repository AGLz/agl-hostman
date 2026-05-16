<?php

namespace App\Validation;

use Illuminate\Validation\Validator;

class SecureValidator extends Validator
{
    public function validateEmail($attribute, $value, $parameters = []): bool
    {
        if (! is_string($value) || filter_var($value, FILTER_VALIDATE_EMAIL) === false) {
            return false;
        }

        [$local, $domain] = explode('@', $value, 2);

        return $local !== ''
            && ! str_ends_with($local, '+')
            && preg_match('/^[A-Za-z0-9._%+-]+$/', $local) === 1
            && preg_match('/^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/', $domain) === 1
            && filter_var($domain, FILTER_VALIDATE_IP) === false;
    }

    public function validateUrl($attribute, $value, $parameters = []): bool
    {
        if (! is_string($value) || filter_var($value, FILTER_VALIDATE_URL) === false) {
            return false;
        }

        $scheme = strtolower((string) parse_url($value, PHP_URL_SCHEME));

        return in_array($scheme, ['http', 'https'], true);
    }

    public function validateBoolean($attribute, $value, $parameters = []): bool
    {
        return is_bool($value) || (is_int($value) && in_array($value, [0, 1], true));
    }
}
