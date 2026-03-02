<?php

namespace Tests\Unit\Helpers;

use PHPUnit\Framework\TestCase;
use App\Helpers\MysqlCompatibility;
use PDO;

/**
 * Unit tests for MySQL Compatibility Shim
 *
 * Location: /var/www/fg_OLD2_NEW/tests/Unit/Helpers/MysqlCompatibilityTest.php
 */
class MysqlCompatibilityTest extends TestCase
{
    private PDO $pdo;

    protected function setUp(): void
    {
        $this->pdo = new PDO('sqlite::memory:');
        $this->pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $this->pdo->exec('CREATE TABLE test_results (id INT, name TEXT, value DECIMAL(10,2))');
        $this->pdo->exec("INSERT INTO test_results VALUES (1, 'Test Item', 1234.56)");
        $this->pdo->exec("INSERT INTO test_results VALUES (2, 'Another Item', 789.00)");
    }

    /** @test */
    public function mysql_result_returns_single_field_by_name()
    {
        $stmt = $this->pdo->query('SELECT * FROM test_results WHERE id = 1');
        $result = mysql_result($stmt, 0, 'name');

        $this->assertEquals('Test Item', $result);
    }

    /** @test */
    public function mysql_result_returns_single_field_by_index()
    {
        $stmt = $this->pdo->query('SELECT * FROM test_results WHERE id = 1');
        $result = mysql_result($stmt, 0, 1);

        $this->assertEquals('Test Item', $result);
    }

    /** @test */
    public function mysql_result_returns_null_for_missing_field()
    {
        $stmt = $this->pdo->query('SELECT * FROM test_results WHERE id = 999');
        $result = mysql_result($stmt, 0, 'name');

        $this->assertNull($result);
    }

    /** @test */
    public function mysql_fetch_assoc_returns_associative_array()
    {
        $stmt = $this->pdo->query('SELECT * FROM test_results WHERE id = 1');
        $result = mysql_fetch_assoc($stmt);

        $this->assertIsArray($result);
        $this->assertEquals(1, $result['id']);
        $this->assertEquals('Test Item', $result['name']);
    }

    /** @test */
    public function mysql_fetch_assoc_returns_null_when_no_rows()
    {
        $stmt = $this->pdo->query('SELECT * FROM test_results WHERE id = 999');
        $result = mysql_fetch_assoc($stmt);

        $this->assertNull($result);
    }

    /** @test */
    public function mysql_fetch_array_returns_both_types()
    {
        $stmt = $this->pdo->query('SELECT * FROM test_results WHERE id = 1');
        $result = mysql_fetch_array($stmt);

        $this->assertIsArray($result);
        // Should have both associative and numeric keys
        $this->assertEquals(1, $result[0]);
        $this->assertEquals(1, $result['id']);
    }

    /** @test */
    public function mysql_num_rows_returns_correct_count()
    {
        $stmt = $this->pdo->query('SELECT * FROM test_results');
        $count = mysql_num_rows($stmt);

        $this->assertEquals(2, $count);
    }

    /** @test */
    public function mysql_num_rows_returns_zero_for_empty_result()
    {
        $stmt = $this->pdo->query('SELECT * FROM test_results WHERE id = 999');
        $count = mysql_num_rows($stmt);

        $this->assertEquals(0, $count);
    }

    /** @test */
    public function class_method_mysql_result_works()
    {
        $stmt = $this->pdo->query('SELECT * FROM test_results WHERE id = 1');
        $result = MysqlCompatibility::mysql_result($stmt, 0, 'name');

        $this->assertEquals('Test Item', $result);
    }
}
