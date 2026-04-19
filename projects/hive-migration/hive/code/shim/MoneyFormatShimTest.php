<?php

namespace Tests\Unit\Helpers;

use PHPUnit\Framework\TestCase;

/**
 * Unit tests for Money Format Shim
 *
 * Location: /var/www/fg_OLD2_NEW/tests/Unit/Helpers/MoneyFormatShimTest.php
 */
class MoneyFormatShimTest extends TestCase
{
    /** @test */
    public function money_format_returns_brl_currency()
    {
        $formatted = money_format('%n', 1234.56);

        // Should contain formatted number
        $this->assertStringContainsString('1.234,56', $formatted);
    }

    /** @test */
    public function money_format_handles_zero()
    {
        $formatted = money_format('%n', 0);

        $this->assertStringContainsString('0,00', $formatted);
    }

    /** @test */
    public function money_format_handles_negative()
    {
        $formatted = money_format('%n', -100.50);

        $this->assertStringContainsString('100,50', $formatted);
    }

    /** @test */
    public function money_format_handles_large_numbers()
    {
        $formatted = money_format('%n', 1234567.89);

        $this->assertStringContainsString('1.234.567,89', $formatted);
    }

    /** @test */
    public function money_format_handles_small_decimals()
    {
        $formatted = money_format('%n', 0.01);

        $this->assertStringContainsString('0,01', $formatted);
    }

    /** @test */
    public function money_format_international_format()
    {
        $formatted = money_format('%i', 100.00);

        // Should format with international currency code
        $this->assertNotEmpty($formatted);
    }

    /** @test */
    public function money_format_function_exists()
    {
        $this->assertTrue(function_exists('money_format'));
    }
}
