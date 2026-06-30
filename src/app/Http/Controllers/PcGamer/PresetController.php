<?php

declare(strict_types=1);

namespace App\Http\Controllers\PcGamer;

use App\Http\Controllers\Controller;
use App\Models\PcGamer\PcgBuildPreset;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class PresetController extends Controller
{
    public function index(Request $request): Response
    {
        $query = PcgBuildPreset::query()->orderBy('tier');

        if ($tier = $request->query('tier')) {
            $query->where('tier', $tier);
        }

        return Inertia::render('PcGamer/Presets/Index', [
            'presets' => $query->get(),
            'filters' => [
                'tier' => is_string($tier) ? $tier : null,
            ],
        ]);
    }
}
