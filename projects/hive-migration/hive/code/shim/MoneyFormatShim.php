<?php

/**
 * money_format() Compatibility Shim for PHP 8.0+
 *
 * money_format() was removed in PHP 8.0
 * This shim uses NumberFormatter as a replacement
 *
 * PHP 7.4 COMPATIBLE - Uses switch instead of match, strpos instead of str_contains
 *
 * Target: /var/www/fg_OLD2_NEW/app/Helpers/MoneyFormatShim.php
 * Critical For: ReciboController.php line 344
 */

if (!function_exists('money_format')) {
    /**
     * money_format() replacement for PHP 8.0+
     *
     * @param string $format Format string (limited support for %n and %i)
     * @param float $number Number to format
     * @return string
     */
    function money_format(string $format, float $number): string
    {
        // Get locale from environment or use default
        $locale = function_exists('env') ? env('APP_LOCALE', 'pt_BR') : 'pt_BR';

        // Create NumberFormatter
        $formatter = new NumberFormatter($locale, NumberFormatter::CURRENCY);

        // Detect currency from locale (PHP 7.4 compatible switch)
        switch ($locale) {
            case 'pt_BR':
                $currency = 'BRL';
                break;
            case 'en_US':
                $currency = 'USD';
                break;
            case 'es_ES':
            case 'es_AR':
                $currency = 'EUR';
                break;
            default:
                $currency = 'USD';
                break;
        }

        // Format based on format string (PHP 7.4 compatible strpos)
        if (strpos($format, '%n') !== false) {
            // National currency format
            return $formatter->formatCurrency($number, $currency);
        }

        if (strpos($format, '%i') !== false) {
            // International currency format
            $formatter->setTextAttribute(NumberFormatter::CURRENCY_CODE, $currency);
            return $formatter->formatCurrency($number, $currency);
        }

        // Fallback: simple formatting
        $formatter = new NumberFormatter($locale, NumberFormatter::DECIMAL);
        $formatter->setAttribute(NumberFormatter::MIN_FRACTION_DIGITS, 2);
        $formatter->setAttribute(NumberFormatter::MAX_FRACTION_DIGITS, 2);

        return $currency . ' ' . $formatter->format($number);
    }
}
