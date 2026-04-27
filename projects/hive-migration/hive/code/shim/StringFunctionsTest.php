<?php

namespace Tests\Unit\Helpers;

use PHPUnit\Framework\TestCase;

/**
 * Unit tests for String Functions Shim
 *
 * Location: /var/www/fg_OLD2_NEW/tests/Unit/Helpers/StringFunctionsTest.php
 */
class StringFunctionsTest extends TestCase
{
    /** @test */
    public function safe_strlen_handles_null()
    {
        $this->assertEquals(0, safe_strlen(null));
    }

    /** @test */
    public function safe_strlen_handles_empty_string()
    {
        $this->assertEquals(0, safe_strlen(''));
    }

    /** @test */
    public function safe_strlen_handles_normal_string()
    {
        $this->assertEquals(5, safe_strlen('hello'));
    }

    /** @test */
    public function safe_str_repeat_handles_null()
    {
        $this->assertEquals('', safe_str_repeat(null, 5));
    }

    /** @test */
    public function safe_str_repeat_handles_zero_times()
    {
        $this->assertEquals('', safe_str_repeat('x', 0));
    }

    /** @test */
    public function safe_str_repeat_handles_negative_times()
    {
        $this->assertEquals('', safe_str_repeat('x', -5));
    }

    /** @test */
    public function safe_str_repeat_normal_operation()
    {
        $this->assertEquals('xxxxx', safe_str_repeat('x', 5));
    }

    /** @test */
    public function zero_pad_adds_leading_zeros()
    {
        $this->assertEquals('00123', zero_pad(123, 5));
    }

    /** @test */
    public function zero_pad_handles_null()
    {
        $this->assertEquals('00000', zero_pad(null, 5));
    }

    /** @test */
    public function zero_pad_handles_already_correct_length()
    {
        $this->assertEquals('12345', zero_pad(12345, 5));
    }

    /** @test */
    public function zero_pad_handles_longer_value()
    {
        $this->assertEquals('123456', zero_pad(123456, 5));
    }

    /** @test */
    public function zero_pad_handles_string_input()
    {
        $this->assertEquals('000AB', zero_pad('AB', 5));
    }

    /** @test */
    public function safe_substr_handles_null()
    {
        $this->assertEquals('', safe_substr(null, 0));
    }

    /** @test */
    public function safe_substr_normal_operation()
    {
        $this->assertEquals('llo', safe_substr('hello', 2));
    }

    /** @test */
    public function safe_substr_with_length()
    {
        $this->assertEquals('el', safe_substr('hello', 1, 2));
    }

    /** @test */
    public function safe_strpos_handles_null()
    {
        $this->assertFalse(safe_strpos(null, 'test'));
    }

    /** @test */
    public function safe_strpos_normal_operation()
    {
        $this->assertEquals(2, safe_strpos('hello', 'l'));
    }

    /** @test */
    public function safe_strpos_not_found()
    {
        $this->assertFalse(safe_strpos('hello', 'z'));
    }

    /** @test */
    public function safe_str_replace_handles_null()
    {
        $this->assertEquals('', safe_str_replace('a', 'b', null));
    }

    /** @test */
    public function safe_str_replace_normal_operation()
    {
        $this->assertEquals('hllo', safe_str_replace('e', '', 'hello'));
    }
}
