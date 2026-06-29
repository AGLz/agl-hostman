<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LlmProbeRun extends Model
{
    protected $fillable = [
        'probe_type',
        'harness',
        'model',
        'latency_ms',
        'result',
        'tokens_in',
        'tokens_out',
        'http_status',
        'meta_json',
    ];

    protected function casts(): array
    {
        return [
            'latency_ms' => 'integer',
            'tokens_in' => 'integer',
            'tokens_out' => 'integer',
            'http_status' => 'integer',
            'meta_json' => 'array',
        ];
    }
}
