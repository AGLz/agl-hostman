<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DORAMetric extends Model
{
    protected $table = 'dora_metrics';

    protected $fillable = [
        'period',
        'deployment_frequency',
        'lead_time',
        'mttr',
        'change_failure_rate',
        'performance_tier',
        'calculated_at',
    ];

    protected $casts = [
        'deployment_frequency' => 'array',
        'lead_time' => 'array',
        'mttr' => 'array',
        'change_failure_rate' => 'array',
        'performance_tier' => 'array',
        'calculated_at' => 'datetime',
    ];
}
