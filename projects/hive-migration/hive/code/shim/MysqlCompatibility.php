<?php

namespace App\Helpers;

/**
 * MySQL Compatibility Shim for PHP 8.1
 *
 * Provides compatibility for removed mysql_* functions
 * by wrapping PDO/MySQLi functionality
 *
 * PHP 7.4 COMPATIBLE - Uses switch instead of match
 *
 * Target: /var/www/fg_OLD2_NEW/app/Helpers/MysqlCompatibility.php
 * Critical For: ReciboController.php (35+ instances)
 */
class MysqlCompatibility
{
    /**
     * Extract a single field from a query result
     *
     * @param mixed $result PDO or MySQLi result object
     * @param int $row Row number
     * @param mixed $field Field index or name
     * @return mixed
     */
    public static function mysql_result($result, int $row = 0, $field = 0)
    {
        if ($result instanceof \PDOStatement) {
            $result->execute();
            $data = $result->fetchAll(\PDO::FETCH_BOTH);
            return isset($data[$row][$field]) ? $data[$row][$field] : null;
        }

        if ($result instanceof \mysqli_result) {
            $result->data_seek($row);
            $row_data = $result->fetch_array(MYSQLI_BOTH);
            return isset($row_data[$field]) ? $row_data[$field] : null;
        }

        throw new \InvalidArgumentException('Unsupported result type');
    }

    /**
     * Fetch associative array from result
     */
    public static function mysql_fetch_assoc($result): ?array
    {
        if ($result instanceof \PDOStatement) {
            $data = $result->fetch(\PDO::FETCH_ASSOC);
            return $data !== false ? $data : null;
        }

        if ($result instanceof \mysqli_result) {
            $data = $result->fetch_assoc();
            return $data !== false && $data !== null ? $data : null;
        }

        return null;
    }

    /**
     * Fetch indexed and associative array
     */
    public static function mysql_fetch_array($result, int $mode = MYSQLI_BOTH): ?array
    {
        if ($result instanceof \PDOStatement) {
            // Convert MySQLi mode to PDO mode
            switch ($mode) {
                case MYSQLI_ASSOC:
                    $pdoMode = \PDO::FETCH_ASSOC;
                    break;
                case MYSQLI_NUM:
                    $pdoMode = \PDO::FETCH_NUM;
                    break;
                default:
                    $pdoMode = \PDO::FETCH_BOTH;
                    break;
            }
            $data = $result->fetch($pdoMode);
            return $data !== false ? $data : null;
        }

        if ($result instanceof \mysqli_result) {
            $data = $result->fetch_array($mode);
            return $data !== false && $data !== null ? $data : null;
        }

        return null;
    }

    /**
     * Count rows in result
     */
    public static function mysql_num_rows($result): int
    {
        if ($result instanceof \PDOStatement) {
            return $result->rowCount();
        }

        if ($result instanceof \mysqli_result) {
            return $result->num_rows;
        }

        return 0;
    }
}

// Global function aliases for drop-in compatibility
if (!function_exists('mysql_result')) {
    function mysql_result($result, int $row = 0, $field = 0) {
        return \App\Helpers\MysqlCompatibility::mysql_result($result, $row, $field);
    }
}

if (!function_exists('mysql_fetch_assoc')) {
    function mysql_fetch_assoc($result): ?array {
        return \App\Helpers\MysqlCompatibility::mysql_fetch_assoc($result);
    }
}

if (!function_exists('mysql_fetch_array')) {
    function mysql_fetch_array($result, int $mode = MYSQLI_BOTH): ?array {
        return \App\Helpers\MysqlCompatibility::mysql_fetch_array($result, $mode);
    }
}

if (!function_exists('mysql_num_rows')) {
    function mysql_num_rows($result): int {
        return \App\Helpers\MysqlCompatibility::mysql_num_rows($result);
    }
}
