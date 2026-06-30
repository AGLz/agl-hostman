<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\PcGamer;

use App\Http\Controllers\Controller;
use App\Models\PcGamer\PcgBuildPreset;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PresetController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = PcgBuildPreset::query()->orderBy('tier');

        if ($tier = $request->query('tier')) {
            $query->where('tier', $tier);
        }

        return response()->json(['data' => $query->get()]);
    }
}
