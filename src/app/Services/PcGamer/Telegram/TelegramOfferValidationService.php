<?php

declare(strict_types=1);

namespace App\Services\PcGamer\Telegram;

use App\Enums\PcGamer\OfferStatus;
use App\Models\PcGamer\PcgTelegramOffer;
use Illuminate\Support\Facades\Log;

class TelegramOfferValidationService
{
    public function __construct(
        private readonly OfferValidatorService $validator,
    ) {}

    /**
     * @return array{validated: int, skipped: int, errors: list<string>}
     */
    public function validateBatch(?int $batch = null): array
    {
        $cfg = config('pcgamer.telegram.validation');
        $maxAgeHours = (int) ($cfg['max_age_hours'] ?? 72);
        $revalidateMinutes = (int) ($cfg['revalidate_minutes'] ?? 30);
        $batchSize = $batch ?? (int) ($cfg['batch'] ?? 25);
        $tolerance = (float) ($cfg['price_tolerance_percent'] ?? 5);

        $offers = PcgTelegramOffer::query()
            ->needsValidation($maxAgeHours, $revalidateMinutes)
            ->orderByDesc('created_at')
            ->limit($batchSize)
            ->get();

        $validated = 0;
        $skipped = 0;
        $errors = [];

        foreach ($offers as $offer) {
            $url = (string) ($offer->url ?? '');
            if ($url === '') {
                $skipped++;

                continue;
            }

            $requirementsNote = $this->requirementsNote($offer->parsed_json ?? []);

            try {
                $result = $this->validator->validateUrl(
                    url: $url,
                    expectedPriceCents: $offer->price_cents,
                    tolerancePercent: $tolerance,
                    requirementsNote: $requirementsNote,
                );
            } catch (\Throwable $e) {
                $errors[] = "offer {$offer->id}: {$e->getMessage()}";
                continue;
            }

            $status = $this->mapStatus($result->status);

            $offer->update([
                'status' => $status,
                'last_validated_at' => now(),
                'validated_price_cents' => $result->validatedPriceCents,
                'validation_notes' => $result->notes,
            ]);

            $validated++;
        }

        Log::info('PC Gamer telegram validation concluída', [
            'validated' => $validated,
            'skipped' => $skipped,
            'errors' => count($errors),
        ]);

        return ['validated' => $validated, 'skipped' => $skipped, 'errors' => $errors];
    }

    /**
     * @param  array<string, mixed>  $parsed
     */
    private function requirementsNote(array $parsed): string
    {
        $req = $parsed['requirements'] ?? [];
        if (! is_array($req)) {
            return '';
        }
        $parts = [];
        if (! empty($req['requires_coins'])) {
            $parts[] = 'requer moedas';
        }
        if (! empty($req['requires_app'])) {
            $parts[] = 'somente app';
        }
        if (! empty($req['coupon_codes']) && is_array($req['coupon_codes'])) {
            $parts[] = 'cupons: ' . implode(', ', $req['coupon_codes']);
        }

        return implode('; ', $parts);
    }

    private function mapStatus(string $status): OfferStatus
    {
        return match ($status) {
            'active' => OfferStatus::Active,
            'unavailable' => OfferStatus::Unavailable,
            'price_changed' => OfferStatus::PriceChanged,
            default => OfferStatus::NeedsManual,
        };
    }
}
