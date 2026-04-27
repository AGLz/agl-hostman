<?php

declare(strict_types=1);

namespace App\Shim;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * LegacyDatabaseShim
 *
 * Provides backward-compatible database access for code migrated from
 * Laravel 5.5 (API1 / fg_OLD2_NEW) to Laravel 8.x (API8 / fg_API8_d).
 *
 * Key differences handled:
 *  - API1 used connection names 'sys', 'mysql_sys', and 'fgdev'
 *  - API8 uses a single 'mysql' connection via Eloquent
 *  - Raw PDO usage in API1 is wrapped through Laravel's query builder
 *
 * Boot via AppServiceProvider::boot():
 *   LegacyDatabaseShim::bootShim();
 */
final class LegacyDatabaseShim
{
    /** Maps legacy API1 connection identifiers to their API8 equivalents. */
    private static array $connectionMap = [
        'sys'       => 'mysql',
        'mysql_sys' => 'mysql',
        'fgdev'     => 'mysql',
    ];

    private static bool $booted = false;

    /**
     * Translate a legacy connection name to the API8 canonical name.
     * Returns the input unchanged when no mapping exists (fail-safe).
     */
    public static function resolveConnection(string $legacyName): string
    {
        return self::$connectionMap[$legacyName] ?? $legacyName;
    }

    /**
     * Execute a raw SQL query through Laravel's DB facade, normalising any
     * legacy connection assumptions.  Returns the result of DB::select() for
     * SELECT statements and DB::statement() for everything else.
     *
     * @param  array<int|string, mixed>  $bindings
     * @return mixed  array<object> for SELECT, bool otherwise
     */
    public static function wrapLegacyQuery(string $rawSql, array $bindings = []): mixed
    {
        $trimmed = ltrim($rawSql);
        $verb    = strtoupper(substr($trimmed, 0, 6));

        return match ($verb) {
            'SELECT' => DB::select($rawSql, $bindings),
            'INSERT' => DB::insert($rawSql, $bindings),
            'UPDATE' => DB::update($rawSql, $bindings),
            'DELETE' => DB::delete($rawSql, $bindings),
            default  => DB::statement($rawSql, $bindings),
        };
    }

    /**
     * Return the current UTC timestamp in MySQL-compatible format.
     * API1 relied on date('Y-m-d H:i:s') scattered across controllers;
     * this centralises the format so timezone changes are a one-liner.
     */
    public static function legacyTimestamp(): string
    {
        return now()->format('Y-m-d H:i:s');
    }

    /**
     * Register the shim with Laravel's service container.
     *
     * Call once inside AppServiceProvider::boot().  Subsequent calls are
     * no-ops so the provider can be registered multiple times safely.
     */
    public static function bootShim(): void
    {
        if (self::$booted) {
            return;
        }

        self::$booted = true;

        // Extend the DB manager so legacy connection names resolve transparently
        // when code calls DB::connection('sys') or DB::connection('mysql_sys').
        $manager = app('db');

        foreach (self::$connectionMap as $legacyName => $canonicalName) {
            // Only register an extension when the legacy name is not already a
            // real connection defined in database.php — prevents overwriting
            // intentional multi-connection setups.
            try {
                $manager->connection($legacyName);
            } catch (\InvalidArgumentException) {
                $manager->extend($legacyName, static fn() => $manager->connection($canonicalName));
                Log::debug("LegacyDatabaseShim: mapped '{$legacyName}' -> '{$canonicalName}'");
            }
        }
    }

    /**
     * Expose the full connection map for introspection / tests.
     *
     * @return array<string, string>
     */
    public static function connectionMap(): array
    {
        return self::$connectionMap;
    }
}
