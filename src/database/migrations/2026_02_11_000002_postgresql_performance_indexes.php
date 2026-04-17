<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Índices PostgreSQL adicionais (AGL-23).
 *
 * A implementação anterior usava CREATE INDEX CONCURRENTLY (proibido dentro da
 * transação das migrações Laravel), predicados com NOW() (não imutáveis em índices
 * parciais no PostgreSQL), colunas inexistentes (ex.: performance_trends.resource_*,
 * audit_logs.resource_*) e nomes duplicados face a 2026_01_16_000001.
 *
 * Índices de performance alinhados ao schema: 2026_01_16_000001_add_performance_indexes
 * e migrações base. Reintroduzir aqui apenas índices validados com SQL explícito
 * e, se necessário, Migration::$withinTransaction = false.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }
    }
};
