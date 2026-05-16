<?php

namespace App\Validation;

use Illuminate\Validation\Validator;

class SecureValidator extends Validator
{
    public function validated(): array
    {
        return $this->sanitize(parent::validated());
    }

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

    private function sanitize(mixed $value): mixed
    {
        if (is_array($value)) {
            return array_map(fn ($item) => $this->sanitize($item), $value);
        }

        if (! is_string($value)) {
            return $value;
        }

        $value = strip_tags($value);
        $value = preg_replace('/\b(DROP\s+TABLE|UNION\s+SELECT)\b/i', '', $value) ?? $value;
        $value = preg_replace('/<script\b[^>]*>(.*?)<\/script>/is', '', $value) ?? $value;

        return trim($value);
    }
}
