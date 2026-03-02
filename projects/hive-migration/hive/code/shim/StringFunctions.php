<?php

/**
 * Null-Safe String Functions for PHP 8.1+
 *
 * PHP 8.1+ triggers deprecation warnings when passing null to string functions
 * This shim provides null-safe wrappers for common string operations
 *
 * Target: /var/www/fg_OLD2_NEW/app/Helpers/StringFunctions.php
 * Critical For: 30+ methods with potential null issues
 */

if (!function_exists('safe_strlen')) {
    /**
     * Null-safe strlen for PHP 8.1+
     *
     * @param string|null $str
     * @return int
     */
    function safe_strlen(?string $str): int
    {
        return strlen($str ?? '');
    }
}

if (!function_exists('safe_str_repeat')) {
    /**
     * Null-safe str_repeat wrapper
     *
     * @param string|null $str
     * @param int $times
     * @return string
     */
    function safe_str_repeat(?string $str, int $times): string
    {
        return str_repeat($str ?? '', max(0, $times));
    }
}

if (!function_exists('zero_pad')) {
    /**
     * Zero-pad a value to specified length
     *
     * Common pattern in codebase:
     *   return str_repeat("0", $num - strlen($val)) . $val;
     *
     * Usage:
     *   return zero_pad($val, $num);
     *
     * @param mixed $val Value to pad
     * @param int $length Target length
     * @return string
     */
    function zero_pad($val, int $length): string
    {
        $val = (string)($val ?? '');
        return str_repeat("0", max(0, $length - strlen($val))) . $val;
    }
}

if (!function_exists('safe_substr')) {
    /**
     * Null-safe substr wrapper
     *
     * @param string|null $str
     * @param int $start
     * @param int|null $length
     * @return string
     */
    function safe_substr(?string $str, int $start, ?int $length = null): string
    {
        if ($str === null) {
            return '';
        }
        return $length !== null ? substr($str, $start, $length) : substr($str, $start);
    }
}

if (!function_exists('safe_strpos')) {
    /**
     * Null-safe strpos wrapper
     *
     * @param string|null $haystack
     * @param string $needle
     * @param int $offset
     * @return int|false
     */
    function safe_strpos(?string $haystack, string $needle, int $offset = 0)
    {
        if ($haystack === null) {
            return false;
        }
        return strpos($haystack, $needle, $offset);
    }
}

if (!function_exists('safe_str_replace')) {
    /**
     * Null-safe str_replace wrapper
     *
     * @param string|array $search
     * @param string|array $replace
     * @param string|null $subject
     * @return string
     */
    function safe_str_replace($search, $replace, ?string $subject): string
    {
        if ($subject === null) {
            return '';
        }
        return str_replace($search, $replace, $subject);
    }
}
