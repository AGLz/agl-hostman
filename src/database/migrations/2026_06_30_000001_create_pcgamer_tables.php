<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Módulo PC Gamer — cotações, ofertas Telegram, builds (prefixo pcg_).
     */
    public function up(): void
    {
        Schema::create('pcg_component_categories', function (Blueprint $table) {
            $table->id();
            $table->string('slug')->unique();
            $table->string('name');
            $table->unsignedSmallInteger('sort_order')->default(0);
        });

        Schema::create('pcg_components', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained('pcg_component_categories');
            $table->string('sku')->nullable();
            $table->string('brand')->nullable();
            $table->string('model');
            $table->json('specs_json')->nullable();
            $table->text('notes')->nullable();
            $table->boolean('active')->default(true);
            $table->timestamps();

            $table->index('category_id');
            $table->index('brand');
        });

        Schema::create('pcg_telegram_sources', function (Blueprint $table) {
            $table->id();
            $table->string('chat_key')->unique();
            $table->string('title')->nullable();
            $table->boolean('enabled')->default(true);
            $table->unsignedBigInteger('last_synced_message_id')->nullable();
            $table->timestamps();
        });

        Schema::create('pcg_telegram_offers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('source_id')->constrained('pcg_telegram_sources');
            $table->unsignedBigInteger('message_id');
            $table->string('message_hash')->unique();
            $table->timestamp('posted_at')->nullable();
            $table->text('raw_text');
            $table->json('parsed_json')->nullable();
            $table->string('product_name')->nullable();
            $table->unsignedInteger('price_cents')->nullable();
            $table->string('currency', 8)->default('BRL');
            $table->text('url')->nullable();
            $table->string('matched_category_slug')->nullable();
            $table->foreignId('matched_component_id')->nullable()->constrained('pcg_components');
            $table->string('status', 32)->default('new');
            $table->timestamp('last_validated_at')->nullable();
            $table->unsignedInteger('validated_price_cents')->nullable();
            $table->string('validation_notes', 500)->nullable();
            $table->timestamps();

            $table->unique(['source_id', 'message_id']);
            $table->index('matched_category_slug');
            $table->index('price_cents');
            $table->index('status');
        });

        Schema::create('pcg_builds', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique();
            $table->string('title');
            $table->string('customer_name')->nullable();
            $table->string('customer_contact')->nullable();
            $table->string('platform', 32)->default('amd');
            $table->string('status', 32)->default('draft');
            $table->decimal('margin_percent', 5, 2)->default(15);
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index('status');
        });

        Schema::create('pcg_build_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('build_id')->constrained('pcg_builds')->cascadeOnDelete();
            $table->string('category_slug');
            $table->foreignId('component_id')->nullable()->constrained('pcg_components');
            $table->foreignId('offer_id')->nullable()->constrained('pcg_telegram_offers');
            $table->string('label');
            $table->unsignedSmallInteger('quantity')->default(1);
            $table->unsignedInteger('unit_cost_cents')->default(0);
            $table->string('source', 32)->default('manual');
            $table->text('notes')->nullable();
            $table->unsignedSmallInteger('sort_order')->default(0);

            $table->index('build_id');
        });

        Schema::create('pcg_build_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('build_id')->constrained('pcg_builds')->cascadeOnDelete();
            $table->string('event_type');
            $table->string('from_status')->nullable();
            $table->string('to_status')->nullable();
            $table->json('payload_json')->nullable();
            $table->text('notes')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index('build_id');
        });

        Schema::create('pcg_retailers', function (Blueprint $table) {
            $table->id();
            $table->string('slug')->unique();
            $table->string('name');
            $table->string('website')->nullable();
            $table->string('configurator_url')->nullable();
            $table->boolean('is_aggregator')->default(false);
            $table->text('notes')->nullable();
        });

        Schema::create('pcg_market_prices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('retailer_id')->constrained('pcg_retailers');
            $table->string('category_slug');
            $table->string('product_name');
            $table->unsignedInteger('price_cents');
            $table->text('url')->nullable();
            $table->timestamp('recorded_at')->useCurrent();
            $table->string('source', 64)->default('manual');
            $table->text('notes')->nullable();

            $table->index('category_slug');
            $table->index('retailer_id');
        });

        Schema::create('pcg_build_presets', function (Blueprint $table) {
            $table->id();
            $table->string('slug')->unique();
            $table->string('name');
            $table->string('tier', 32);
            $table->string('platform', 32)->default('amd_am5');
            $table->string('reference_site')->nullable();
            $table->text('description')->nullable();
            $table->unsignedInteger('total_reference_cents')->default(0);
            $table->json('items_json');
            $table->timestamp('updated_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pcg_build_events');
        Schema::dropIfExists('pcg_build_items');
        Schema::dropIfExists('pcg_builds');
        Schema::dropIfExists('pcg_telegram_offers');
        Schema::dropIfExists('pcg_telegram_sources');
        Schema::dropIfExists('pcg_market_prices');
        Schema::dropIfExists('pcg_build_presets');
        Schema::dropIfExists('pcg_retailers');
        Schema::dropIfExists('pcg_components');
        Schema::dropIfExists('pcg_component_categories');
    }
};
