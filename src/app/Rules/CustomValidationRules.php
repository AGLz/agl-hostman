<?php

declare(strict_types=1);

namespace App\Rules;

use Illuminate\Contracts\Validation\Rule;

/**
 * VMID Validation Rule
 *
 * Validates Proxmox VMID format and availability.
 */
class ValidVmid implements Rule
{
    /**
     * Determine if the validation rule passes.
     *
     * @param  string  $attribute
     * @param  mixed  $value
     */
    public function passes($attribute, $value): bool
    {
        // VMID must be integer between 100 and 999999999
        if (! is_numeric($value)) {
            return false;
        }

        $vmid = (int) $value;

        return $vmid >= 100 && $vmid <= 999999999;
    }

    /**
     * Get the validation error message.
     */
    public function message(): string
    {
        return 'The :attribute must be a valid VMID between 100 and 999999999.';
    }
}

/**
 * ValidHostname Validation Rule
 *
 * Validates hostname format according to RFC 1123.
 */
class ValidHostname implements Rule
{
    /**
     * Determine if the validation rule passes.
     *
     * @param  string  $attribute
     * @param  mixed  $value
     */
    public function passes($attribute, $value): bool
    {
        if (empty($value)) {
            return true;
        }

        // Hostname regex based on RFC 1123
        $pattern = '/^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])\.)*'.
                    '([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])$/';

        return preg_match($pattern, $value) === 1;
    }

    /**
     * Get the validation error message.
     */
    public function message(): string
    {
        return 'The :attribute is not a valid hostname.';
    }
}

/**
 * ValidIPAddress Validation Rule
 *
 * Validates IP address (IPv4 or IPv6) with optional CIDR notation.
 */
class ValidIPAddress implements Rule
{
    private bool $allowCidr;

    private array $allowedRanges;

    public function __construct(bool $allowCidr = false, array $allowedRanges = [])
    {
        $this->allowCidr = $allowCidr;
        $this->allowedRanges = $allowedRanges;
    }

    /**
     * Determine if the validation rule passes.
     *
     * @param  string  $attribute
     * @param  mixed  $value
     */
    public function passes($attribute, $value): bool
    {
        if (empty($value)) {
            return true;
        }

        // Check if it's a valid IP address
        $isValidIp = filter_var($value, FILTER_VALIDATE_IP) !== false;

        if (! $isValidIp) {
            return false;
        }

        // If CIDR is allowed, check for CIDR notation
        if ($this->allowCidr) {
            $hasCidr = strpos($value, '/') !== false;
            if ($hasCidr) {
                return $this->isValidCidr($value);
            }
        }

        // Check if IP is in allowed ranges
        if (! empty($this->allowedRanges)) {
            return $this->isInAllowedRange($value);
        }

        return true;
    }

    /**
     * Validate CIDR notation
     */
    private function isValidCidr(string $ip): bool
    {
        return filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4 | FILTER_FLAG_IPV6) !== false;
    }

    /**
     * Check if IP is in allowed ranges
     */
    private function isInAllowedRange(string $ip): bool
    {
        foreach ($this->allowedRanges as $range) {
            if ($this->ipInRange($ip, $range)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Check if IP is in CIDR range
     */
    private function ipInRange(string $ip, string $range): bool
    {
        [$range, $netmask] = explode('/', $range);
        $rangeDecimal = ip2long($range);
        $ipDecimal = ip2long($ip);
        $maskDecimal = ~((1 << (32 - $netmask)) - 1);

        return ($ipDecimal & $maskDecimal) === ($rangeDecimal & $maskDecimal);
    }

    /**
     * Get the validation error message.
     */
    public function message(): string
    {
        return 'The :attribute must be a valid IP address.';
    }
}

/**
 * StrongPassword Validation Rule
 *
 * Validates password strength requirements.
 */
class StrongPassword implements Rule
{
    private int $minLength;

    private bool $requireUppercase;

    private bool $requireLowercase;

    private bool $requireNumber;

    private bool $requireSpecialChar;

    public function __construct(
        int $minLength = 12,
        bool $requireUppercase = true,
        bool $requireLowercase = true,
        bool $requireNumber = true,
        bool $requireSpecialChar = true
    ) {
        $this->minLength = $minLength;
        $this->requireUppercase = $requireUppercase;
        $this->requireLowercase = $requireLowercase;
        $this->requireNumber = $requireNumber;
        $this->requireSpecialChar = $requireSpecialChar;
    }

    /**
     * Determine if the validation rule passes.
     *
     * @param  string  $attribute
     * @param  mixed  $value
     */
    public function passes($attribute, $value): bool
    {
        if (strlen($value) < $this->minLength) {
            return false;
        }

        if ($this->requireUppercase && ! preg_match('/[A-Z]/', $value)) {
            return false;
        }

        if ($this->requireLowercase && ! preg_match('/[a-z]/', $value)) {
            return false;
        }

        if ($this->requireNumber && ! preg_match('/[0-9]/', $value)) {
            return false;
        }

        if ($this->requireSpecialChar && ! preg_match('/[!@#$%^&*()_+\-=\[\]{};:"\\|,<\.>\/?]/', $value)) {
            return false;
        }

        return true;
    }

    /**
     * Get the validation error message.
     */
    public function message(): string
    {
        $messages = [];

        $messages[] = "Password must be at least {$this->minLength} characters long.";

        if ($this->requireUppercase) {
            $messages[] = 'contain at least one uppercase letter.';
        }

        if ($this->requireLowercase) {
            $messages[] = 'contain at least one lowercase letter.';
        }

        if ($this->requireNumber) {
            $messages[] = 'contain at least one number.';
        }

        if ($this->requireSpecialChar) {
            $messages[] = 'contain at least one special character.';
        }

        $prefix = 'The :attribute must ';
        $suffix = '.';

        return $prefix.implode(' ', $messages).$suffix;
    }
}

/**
 * SafeUrl Validation Rule
 *
 * Validates URL to prevent SSRF attacks.
 */
class SafeUrl implements Rule
{
    private array $allowedHosts;

    public function __construct(array $allowedHosts = [])
    {
        $this->allowedHosts = $allowedHosts;
    }

    /**
     * Determine if the validation rule passes.
     *
     * @param  string  $attribute
     * @param  mixed  $value
     */
    public function passes($attribute, $value): bool
    {
        if (empty($value)) {
            return true;
        }

        // Validate URL format
        if (! filter_var($value, FILTER_VALIDATE_URL)) {
            return false;
        }

        $host = parse_url($value, PHP_URL_HOST);

        if (! $host) {
            return false;
        }

        // Check if host is in allowed list
        if (! empty($this->allowedHosts)) {
            return in_array($host, $this->allowedHosts);
        }

        // Prevent internal network access (SSRF protection)
        if ($this->isPrivateIp($host)) {
            return false;
        }

        // Prevent local file access
        if (str_starts_with(strtolower($value), 'file://')) {
            return false;
        }

        return true;
    }

    /**
     * Check if IP is private/internal
     */
    private function isPrivateIp(string $host): bool
    {
        $ip = gethostbyname($host);

        if ($ip === $host) {
            // Not a valid IP, hostname lookup failed
            return false;
        }

        $privateRanges = [
            '10.0.0.0/8',
            '172.16.0.0/12',
            '192.168.0.0/16',
            '127.0.0.0/8',
            '169.254.0.0/16',
        ];

        foreach ($privateRanges as $range) {
            if ($this->ipInRange($ip, $range)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Check if IP is in CIDR range
     */
    private function ipInRange(string $ip, string $range): bool
    {
        [$range, $netmask] = explode('/', $range);
        $rangeDecimal = ip2long($range);
        $ipDecimal = ip2long($ip);
        $maskDecimal = ~((1 << (32 - $netmask)) - 1);

        return ($ipDecimal & $maskDecimal) === ($rangeDecimal & $maskDecimal);
    }

    /**
     * Get the validation error message.
     */
    public function message(): string
    {
        return 'The :attribute must be a valid, safe URL.';
    }
}

/**
 * ValidJson Validation Rule
 *
 * Validates JSON string.
 */
class ValidJson implements Rule
{
    /**
     * Determine if the validation rule passes.
     *
     * @param  string  $attribute
     * @param  mixed  $value
     */
    public function passes($attribute, $value): bool
    {
        if (empty($value)) {
            return true;
        }

        json_decode($value);

        return json_last_error() === JSON_ERROR_NONE;
    }

    /**
     * Get the validation error message.
     */
    public function message(): string
    {
        return 'The :attribute must be a valid JSON string.';
    }
}
