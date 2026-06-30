<?php

declare(strict_types=1);

namespace App\Services\PcGamer\Telegram;

/**
 * Parser heurístico de ofertas Telegram (PT-BR) — port do sidecar Python.
 */
class OfferParser
{
    /** @var array<string, list<string>> */
    private const CATEGORY_KEYWORDS = [
        'placa_video' => ['rtx', 'gtx', 'rx ', 'radeon', 'placa de video', 'placa de vídeo', 'gpu', 'geforce'],
        'motherboard' => ['placa mae', 'placa-mãe', 'placa mãe', 'motherboard', 'b650', 'b850', 'x670', 'x870', 'am5'],
        'memoria_ddr5' => ['ddr5', 'memoria', 'memória', 'ram', 'fury', 'vengeance'],
        'nvme' => ['nvme', 'm.2', 'ssd', 'samsung 990', 'samsung 980', 'sn850'],
        'processador' => ['ryzen', 'processador', 'cpu', '7950x', '7800x3d', '7600'],
        'fonte' => ['fonte', 'psu', 'power supply', '80 plus', 'gold', 'platinum'],
        'gabinete' => ['gabinete', 'case', 'mid tower', 'full tower'],
        'water_cooler' => ['water cooler', 'aio', 'liquid cooler', 'arctic liquid'],
        'fan' => ['fan', 'ventoinha', 'cooler master', 'pwm', '120mm', '140mm'],
        'suporte_vga' => ['suporte vga', 'gpu bracket', 'anti sag', 'rise', 'holder'],
    ];

    /** @var array<string, list<string>> */
    private const RETAILER_DOMAINS = [
        'aliexpress' => ['aliexpress.com', 'a.aliexpress.com', 's.click.aliexpress.com'],
        'shopee' => ['shopee.com.br', 's.shopee.com.br'],
        'mercadolivre' => ['mercadolivre.com.br', 'meli.la', 'mercadolibre.com'],
        'kabum' => ['kabum.com.br', 'tidd.ly'],
        'terabyte' => ['terabyteshop.com.br', 'terabyte.com.br', 'aoferta.net'],
        'amazon' => ['amazon.com.br', 'amzn.to', 'amzn.com'],
        'magalu' => ['magazineluiza.com.br', 'magalu.com'],
        'pichau' => ['pichau.com.br'],
    ];

    /** @var list<string> */
    private const BRAND_HINTS = ['asus', 'gigabyte', 'msi', 'asrock', 'samsung', 'corsair', 'kingston'];

    public function messageHash(string $text, string $chatKey, int $messageId): string
    {
        return hash('sha256', "{$chatKey}:{$messageId}:" . trim($text));
    }

    /**
     * @return array<string, mixed>
     */
    public function parse(string $text): array
    {
        [$category, $confidence, $keywords] = $this->detectCategory($text);
        $priceCents = $this->extractPrice($text);
        $url = $this->pickProductUrl($text);
        $productName = $this->extractProductName($text);
        $requirements = $this->extractRequirements($text, $url);

        if ($productName !== null) {
            $lowerName = strtolower($productName);
            foreach (self::BRAND_HINTS as $brand) {
                if (str_contains($lowerName, $brand)) {
                    $confidence = min($confidence + 0.15, 1.0);
                    break;
                }
            }
        }
        if ($requirements['coupon_codes'] !== [] || $requirements['requires_coins']) {
            $confidence = min($confidence + 0.05, 1.0);
        }

        return [
            'product_name' => $productName,
            'price_cents' => $priceCents,
            'currency' => 'BRL',
            'url' => $url,
            'matched_category_slug' => $category,
            'confidence' => $confidence,
            'keywords' => $keywords,
            'requirements' => $requirements,
        ];
    }

    public function extractPrice(string $text): ?int
    {
        $candidates = [];
        if (preg_match_all('/(?:r\$|rs\.?)\s*([\d][\d.\s,]*)/iu', $text, $matches)) {
            foreach ($matches[1] as $raw) {
                $cents = $this->parsePriceCents($raw);
                if ($cents !== null && $cents >= 1000) {
                    $candidates[] = $cents;
                }
            }
        }
        if ($candidates === []) {
            return null;
        }
        $plausible = array_values(array_filter($candidates, fn(int $c) => $c <= 50_000_000));

        return $plausible !== [] ? max($plausible) : max($candidates);
    }

    private function parsePriceCents(string $raw): ?int
    {
        $token = explode(' ', trim($raw))[0] ?? '';
        $token = str_replace(' ', '', $token);
        if ($token === '') {
            return null;
        }

        if (str_contains($token, ',')) {
            $cleaned = str_replace(['.', ','], ['', '.'], $token);
        } elseif (substr_count($token, '.') >= 1 && strlen(explode('.', $token)[count(explode('.', $token)) - 1]) === 3) {
            $cleaned = str_replace('.', '', $token);
        } elseif (substr_count($token, '.') === 1 && strlen(explode('.', $token)[1]) <= 2) {
            $cleaned = $token;
        } else {
            $cleaned = str_replace('.', '', $token);
        }

        if (! is_numeric($cleaned)) {
            return null;
        }
        $value = (float) $cleaned;
        if ($value <= 0) {
            return null;
        }

        return (int) round($value * 100);
    }

    /**
     * @return array{0: ?string, 1: float, 2: list<string>}
     */
    private function detectCategory(string $text): array
    {
        $lowered = strtolower($text);
        $bestSlug = null;
        $bestScore = 0.0;
        $hits = [];

        foreach (self::CATEGORY_KEYWORDS as $slug => $keywords) {
            $score = 0.0;
            $localHits = [];
            foreach ($keywords as $keyword) {
                if (str_contains($lowered, $keyword)) {
                    $score += 1.0;
                    $localHits[] = $keyword;
                }
            }
            if ($score > $bestScore) {
                $bestScore = $score;
                $bestSlug = $slug;
                $hits = $localHits;
            }
        }

        $confidence = $bestSlug !== null ? min($bestScore / 3.0, 1.0) : 0.0;

        return [$bestSlug, $confidence, $hits];
    }

    private function extractProductName(string $text): ?string
    {
        $lines = array_values(array_filter(array_map('trim', preg_split('/\R/', $text) ?: [])));
        if ($lines === []) {
            return null;
        }

        $candidates = [];
        foreach (array_slice($lines, 0, 4) as $line) {
            if (preg_match('/https?:\/\//i', $line)) {
                continue;
            }
            if (preg_match('/^r\$/i', $line)) {
                continue;
            }
            if (strlen($line) >= 8) {
                $candidates[] = $line;
            }
        }

        if ($candidates !== []) {
            return mb_substr($candidates[0], 0, 240);
        }

        return mb_substr($lines[0], 0, 240);
    }

    private function pickProductUrl(string $text): ?string
    {
        $urls = $this->extractAllUrls($text);
        if ($urls === []) {
            return null;
        }
        $productHints = ['produto', 'product', 'item', 'aliexpress.com/_', 'shopee.com.br', 'mercadolivre.com.br', 'kabum.com.br', 'terabyte', 'amazon.com.br'];
        foreach ($urls as $url) {
            $lower = strtolower($url);
            foreach ($productHints as $hint) {
                if (str_contains($lower, $hint)) {
                    return $url;
                }
            }
        }

        return $urls[array_key_last($urls)];
    }

    /** @return list<string> */
    private function extractAllUrls(string $text): array
    {
        $urls = [];
        if (preg_match_all('/https?:\/\/[^\s<>"\']+/i', $text, $matches)) {
            foreach ($matches[0] as $url) {
                $urls[] = rtrim($url, ').,]');
            }
        }

        return $urls;
    }

    /**
     * @return array<string, mixed>
     */
    private function extractRequirements(string $text, ?string $url): array
    {
        $lowered = strtolower($text);
        $conditions = [];

        $requiresCoins = $this->containsAny($lowered, ['moedas', 'super moedas', 'super moeda', 'coins', 'moeda no app']);
        $requiresApp = $this->containsAny($lowered, ['somente no app', 'só no app', 'only app', 'no app com moedas', 'no app,']);
        $requiresPix = $this->containsAny($lowered, ['pix', 'pagamento pix', 'só pix', 'somente pix', 'pague com pix']);
        $isFlash = $this->containsAny($lowered, ['esgota', 'correria', 'limitado', 'relâmpago', 'relampago', 'flash', 'age rápido', 'age rapido', 'muito rapido', 'muito rápido', 'nao espera', 'não espera']);

        if ($requiresCoins) {
            $conditions[] = 'moedas';
        }
        if ($requiresApp) {
            $conditions[] = 'app_only';
        }
        if ($requiresPix) {
            $conditions[] = 'pix';
        }
        if ($isFlash) {
            $conditions[] = 'flash';
        }

        $retailer = $this->detectRetailer($text, $url);
        if ($retailer === 'aliexpress' && ! $requiresCoins && str_contains($lowered, 'aliexpress') && str_contains($lowered, 'app')) {
            $requiresApp = true;
            if (! in_array('app_only', $conditions, true)) {
                $conditions[] = 'app_only';
            }
        }

        return [
            'requires_coins' => $requiresCoins,
            'requires_app' => $requiresApp,
            'requires_pix' => $requiresPix,
            'coupon_codes' => $this->extractCouponCodes($text),
            'retailer' => $retailer,
            'is_flash' => $isFlash,
            'conditions' => $conditions,
        ];
    }

    /** @param list<string> $needles */
    private function containsAny(string $haystack, array $needles): bool
    {
        foreach ($needles as $needle) {
            if (str_contains($haystack, $needle)) {
                return true;
            }
        }

        return false;
    }

    private function detectRetailer(string $text, ?string $url): ?string
    {
        $haystack = strtolower($text . "\n" . ($url ?? ''));
        foreach (self::RETAILER_DOMAINS as $slug => $domains) {
            foreach ($domains as $domain) {
                if (str_contains($haystack, $domain)) {
                    return $slug;
                }
            }
        }

        return null;
    }

    /** @return list<string> */
    private function extractCouponCodes(string $text): array
    {
        $found = [];
        $seen = [];
        $patterns = [
            '/`([A-Z0-9][A-Z0-9_-]{3,23})`/i',
            '/cupom[:\s]+`?([A-Z0-9][A-Z0-9_-]{3,23})`?/i',
            '/c[oó]digo[:\s]+`?([A-Z0-9][A-Z0-9_-]{3,23})`?/i',
        ];
        foreach ($patterns as $pattern) {
            if (preg_match_all($pattern, $text, $matches)) {
                foreach ($matches[1] as $code) {
                    $upper = strtoupper($code);
                    if (isset($seen[$upper])) {
                        continue;
                    }
                    $seen[$upper] = true;
                    $found[] = $upper;
                }
            }
        }

        return $found;
    }
}
