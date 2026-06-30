<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\PcGamer;

use App\Http\Controllers\Controller;
use App\Http\Requests\PcGamer\StoreTelegramOfferRequest;
use App\Models\PcGamer\PcgTelegramOffer;
use App\Services\PcGamer\TelegramOfferIngestService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TelegramOfferController extends Controller
{
    public function __construct(
        private readonly TelegramOfferIngestService $ingestService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $query = PcgTelegramOffer::query()->with('source');

        if ($category = $request->query('category')) {
            $query->where('matched_category_slug', $category);
        }
        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        $limit = min((int) $request->query('limit', 20), 100);

        $offers = $query
            ->orderByDesc('posted_at')
            ->orderByDesc('id')
            ->limit($limit)
            ->get();

        return response()->json(['data' => $offers]);
    }

    public function store(StoreTelegramOfferRequest $request): JsonResponse
    {
        $validated = $request->validated();

        $result = $this->ingestService->ingest(
            chatKey: $validated['chat_key'],
            messageId: (int) $validated['message_id'],
            messageHash: $validated['message_hash'],
            rawText: $validated['raw_text'],
            parsed: $validated['parsed'],
            postedAt: $validated['posted_at'] ?? null,
            sourceTitle: $validated['source_title'] ?? null,
        );

        if (! $result['created']) {
            return response()->json([
                'success' => true,
                'created' => false,
                'message' => 'Oferta já existente (message_hash duplicado)',
            ]);
        }

        return response()->json([
            'success' => true,
            'created' => true,
            'offer_id' => $result['offer_id'],
        ], 201);
    }
}
