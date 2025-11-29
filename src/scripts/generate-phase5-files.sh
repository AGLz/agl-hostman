#!/bin/bash

# Phase 5 File Generation Script
# Generates all remaining Phase 5 components

set -e

echo "🚀 Generating Phase 5: Advanced Features & DORA Metrics"
echo "=========================================================="

BASE_DIR="/mnt/overpower/apps/dev/agl/agl-hostman/src"

# Create DORA Metrics migration and model
echo "📊 Creating DORA metrics database components..."

cat > "$BASE_DIR/database/migrations/2025_11_27_000002_create_dora_metrics_table.php" <<'EOFMIG'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('dora_metrics', function (Blueprint $table) {
            $table->id();
            $table->string('period'); // day, week, month, quarter
            $table->json('deployment_frequency');
            $table->json('lead_time');
            $table->json('mttr');
            $table->json('change_failure_rate');
            $table->json('performance_tier');
            $table->timestamp('calculated_at');
            $table->timestamps();

            $table->index(['period', 'calculated_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dora_metrics');
    }
};
EOFMIG

cat > "$BASE_DIR/app/Models/DORAMetric.php" <<'EOFMODEL'
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
EOFMODEL

echo "✅ DORA metrics database components created"

# Create DORA calculation command
echo "⚙️ Creating DORA metrics calculation command..."

cat > "$BASE_DIR/app/Console/Commands/DORAMetricsCalculate.php" <<'EOFCMD'
<?php

namespace App\Console\Commands;

use App\Services\Metrics\DORAMetricsService;
use Illuminate\Console\Command;

class DORAMetricsCalculate extends Command
{
    protected $signature = 'dora:calculate {period=week}';
    protected $description = 'Calculate and store DORA metrics';

    public function handle(DORAMetricsService $service): int
    {
        $period = $this->argument('period');

        $this->info("Calculating DORA metrics for period: {$period}");

        $metrics = $service->calculateAllMetrics($period);

        $this->table(
            ['Metric', 'Value', 'Tier'],
            [
                ['Deployment Frequency', $metrics['deployment_frequency']['per_day'] . ' /day', $metrics['deployment_frequency']['tier']],
                ['Lead Time', $metrics['lead_time']['average_hours'] . ' hours', $metrics['lead_time']['tier']],
                ['MTTR', $metrics['mttr']['average_hours'] . ' hours', $metrics['mttr']['tier']],
                ['Change Failure Rate', $metrics['change_failure_rate']['failure_rate_pct'] . '%', $metrics['change_failure_rate']['tier']],
            ]
        );

        $this->info("\nPerformance Tier: " . $metrics['performance_tier']['tier']);

        $service->storeMetricsSnapshot($period);

        $this->info("\n✅ Metrics calculated and stored");

        return 0;
    }
}
EOFCMD

echo "✅ DORA calculation command created"

# Make scripts executable
chmod +x "$BASE_DIR/scripts/detect-affected-tests.sh"
chmod +x "$BASE_DIR/scripts/generate-phase5-files.sh"

echo ""
echo "✅ Phase 5 file generation complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Run migrations: php artisan migrate"
echo "  2. Test affected tests: ./scripts/detect-affected-tests.sh"
echo "  3. Calculate DORA metrics: php artisan dora:calculate"
echo "  4. Review training documentation in docs/"
