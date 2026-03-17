<?php

declare(strict_types=1);

namespace App\Shim;

/**
 * FeatureFlags
 *
 * Controls gradual rollout of API8 route groups during the
 * API1 (fg_OLD2_NEW) → API8 (fg_API8_d) migration.
 *
 * When a flag is ON for a group, requests are forwarded to API8.
 * When OFF, requests remain on API1 (safe default).
 *
 * Flags are persisted to a JSON file so the state survives PHP-FPM
 * restarts and is shared across all worker processes on the same host.
 *
 * Usage:
 *   FeatureFlags::isEnabled('auth');    // bool
 *   FeatureFlags::enable('properties');
 *   FeatureFlags::disableAll();          // instant rollback
 */
final class FeatureFlags
{
    private static string $flagsFile = '/tmp/hostman-feature-flags.json';

    /**
     * Default state for every known group.
     * All OFF — requests start on API1 and are promoted to API8 deliberately.
     *
     * @var array<string, bool>
     */
    private static array $defaults = [
        'auth'       => false,
        'properties' => false,
        'users'      => false,
        'financial'  => false,
        'contracts'  => false,
        'reports'    => false,
        'settings'   => false,
    ];

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    /** Return true when the named group should route to API8. */
    public static function isEnabled(string $group): bool
    {
        $flags = self::load();
        return (bool) ($flags[$group] ?? false);
    }

    /** Route the named group to API8. */
    public static function enable(string $group): void
    {
        $flags         = self::load();
        $flags[$group] = true;
        self::save($flags);
    }

    /** Route the named group back to API1. */
    public static function disable(string $group): void
    {
        $flags         = self::load();
        $flags[$group] = false;
        self::save($flags);
    }

    /** Route all known groups to API8 (full cut-over). */
    public static function enableAll(): void
    {
        $flags = self::load();
        foreach (array_keys(self::$defaults) as $group) {
            $flags[$group] = true;
        }
        self::save($flags);
    }

    /** Revert all groups to API1 (emergency rollback). */
    public static function disableAll(): void
    {
        self::save(array_map(static fn() => false, self::$defaults));
    }

    /**
     * Return the complete flag state.
     *
     * @return array<string, bool>
     */
    public static function getAll(): array
    {
        return self::load();
    }

    /**
     * Override the storage path — primarily for unit tests.
     * Call before any other method in test setUp().
     */
    public static function setFlagsFile(string $path): void
    {
        self::$flagsFile = $path;
    }

    // -------------------------------------------------------------------------
    // Storage helpers
    // -------------------------------------------------------------------------

    /**
     * Load flags from the JSON file, merging with defaults so newly added
     * groups appear as OFF without requiring a file migration.
     *
     * @return array<string, bool>
     */
    private static function load(): array
    {
        if (!is_readable(self::$flagsFile)) {
            return self::$defaults;
        }

        $json = file_get_contents(self::$flagsFile);

        if ($json === false || $json === '') {
            return self::$defaults;
        }

        $decoded = json_decode($json, associative: true);

        if (!is_array($decoded)) {
            return self::$defaults;
        }

        // Merge so that defaults supply any groups missing from the persisted file.
        return array_merge(
            self::$defaults,
            array_map('boolval', $decoded)
        );
    }

    /**
     * Persist the flag state atomically using a write-then-rename pattern to
     * avoid partial reads by concurrent processes.
     *
     * @param  array<string, bool>  $flags
     */
    private static function save(array $flags): void
    {
        $json = json_encode($flags, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR);
        $tmp  = self::$flagsFile . '.tmp.' . getmypid();

        file_put_contents($tmp, $json, LOCK_EX);
        rename($tmp, self::$flagsFile);
    }
}
