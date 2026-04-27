<?php

declare(strict_types=1);

namespace App\Shim;

/**
 * RouteMapper
 *
 * Translates API1 (fg_OLD2_NEW, 126 controllers, api.falg.com.br) route paths
 * to their API8 (fg_API8_d, 75 controllers, api8.falg.com.br) equivalents.
 *
 * Mapping strategy:
 *  - Exact prefix match is attempted first (highest confidence: 1.0).
 *  - When no match is found, null / empty results are returned so callers can
 *    fall back to proxying the request to API1 unchanged.
 *
 * Usage:
 *   $api8Path = RouteMapper::map('/api/imovel/42');
 *   // => '/api/v8/properties/42'  (suffix preserved)
 */
final class RouteMapper
{
    /**
     * API1 prefix → API8 prefix lookup table.
     * Longer prefixes are checked first to avoid short-prefix shadowing.
     *
     * @var array<string, string>
     */
    private static array $routeMap = [
        // Auth
        '/api/login'                => '/api/v8/auth/login',
        '/api/logout'               => '/api/v8/auth/logout',
        '/api/register'             => '/api/v8/auth/register',

        // Properties (imóveis) — more specific entries before generic ones
        '/api/busca'                => '/api/v8/properties/search',
        '/api/search'               => '/api/v8/properties/search',
        '/api/destaque'             => '/api/v8/properties/featured',
        '/api/imoveis'              => '/api/v8/properties',
        '/api/imovel'               => '/api/v8/properties',
        '/api/properties'           => '/api/v8/properties',

        // Users
        '/api/perfil'               => '/api/v8/users/profile',
        '/api/usuarios'             => '/api/v8/users',
        '/api/usuario'              => '/api/v8/users',
        '/api/users'                => '/api/v8/users',

        // Contracts / Documents
        '/api/contratos'            => '/api/v8/contracts',
        '/api/contrato'             => '/api/v8/contracts',
        '/api/documentos'           => '/api/v8/documents',

        // Financial
        '/api/boleto'               => '/api/v8/financial/boleto',
        '/api/pagamento'            => '/api/v8/financial/payment',
        '/api/financeiro'           => '/api/v8/financial',

        // Reports
        '/api/relatorios'           => '/api/v8/reports',
        '/api/relatorio'            => '/api/v8/reports',

        // Config / System
        '/api/config'               => '/api/v8/settings',
        '/api/parametros'           => '/api/v8/settings',
    ];

    /**
     * Confidence scores by match type.
     * Exact prefix match = 1.0; no match = 0.0.
     */
    private const CONFIDENCE_EXACT = 1.0;
    private const CONFIDENCE_NONE  = 0.0;

    /**
     * Translate an API1 path to an API8 path, preserving any suffix after the
     * matched prefix (e.g. path parameters, nested resource IDs).
     *
     * Returns null when no mapping is defined for the given path.
     */
    public static function map(string $api1Path): ?string
    {
        [$api8Prefix, $suffix] = self::findPrefix($api1Path);

        if ($api8Prefix === null) {
            return null;
        }

        return $api8Prefix . $suffix;
    }

    /**
     * Return a structured result for a given HTTP method + path combination.
     *
     * Shape: ['path' => string, 'mapped' => string|null, 'confidence' => float]
     *
     * @return array{path: string, mapped: string|null, confidence: float}
     */
    public static function mapWithMethod(string $method, string $path): array
    {
        $mapped     = self::map($path);
        $confidence = $mapped !== null ? self::CONFIDENCE_EXACT : self::CONFIDENCE_NONE;

        return [
            'path'       => $path,
            'mapped'     => $mapped,
            'confidence' => $confidence,
        ];
    }

    /**
     * Report whether the given API1 path has a known API8 counterpart.
     */
    public static function isFullyMigrated(string $path): bool
    {
        return self::map($path) !== null;
    }

    /**
     * Return the complete route map (API1 prefix => API8 prefix).
     *
     * @return array<string, string>
     */
    public static function getAllMappings(): array
    {
        return self::$routeMap;
    }

    /**
     * Filter a list of API1 paths to those without a defined API8 mapping.
     *
     * Useful for gap analysis: pass all known API1 routes and receive the ones
     * that still need to be implemented in API8.
     *
     * @param  string[]             $api1Routes
     * @return string[]
     */
    public static function unmappedRoutes(array $api1Routes): array
    {
        return array_values(
            array_filter($api1Routes, static fn(string $r) => !self::isFullyMigrated($r))
        );
    }

    /**
     * Locate the longest matching API1 prefix for $path and return the
     * corresponding API8 prefix plus the unmatched suffix.
     *
     * Longest-prefix-match prevents '/api/imovel' from matching '/api/imoveis'.
     *
     * @return array{0: string|null, 1: string}  [api8Prefix|null, suffix]
     */
    private static function findPrefix(string $path): array
    {
        $bestLen    = 0;
        $bestTarget = null;

        foreach (self::$routeMap as $api1Prefix => $api8Prefix) {
            $len = strlen($api1Prefix);

            if ($len <= $bestLen) {
                continue;
            }

            // Match exact prefix followed by '/', '?', or end-of-string.
            if (
                str_starts_with($path, $api1Prefix)
                && (
                    strlen($path) === $len
                    || $path[$len] === '/'
                    || $path[$len] === '?'
                )
            ) {
                $bestLen    = $len;
                $bestTarget = [$api8Prefix, substr($path, $len)];
            }
        }

        return $bestTarget ?? [null, ''];
    }
}
