<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('agent_registrations', function (Blueprint $table) {
            $table->id();
            $table->string('registration_id', 64)->unique();
            $table->string('registration_type', 32);
            $table->string('status', 32)->default('pending_claim');
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('api_key_id')->nullable()->constrained('api_keys')->nullOnDelete();
            $table->unsignedBigInteger('personal_access_token_id')->nullable();
            $table->string('credential_type', 32)->nullable();
            $table->json('scopes')->nullable();
            $table->json('post_claim_scopes')->nullable();
            $table->string('claim_token_hash', 64)->nullable();
            $table->string('claim_view_token_hash', 64)->nullable();
            $table->string('claim_email')->nullable();
            $table->string('otp_hash', 64)->nullable();
            $table->timestamp('otp_expires_at')->nullable();
            $table->string('provider_iss')->nullable();
            $table->string('provider_sub')->nullable();
            $table->string('provider_jti', 64)->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamp('claimed_at')->nullable();
            $table->timestamp('revoked_at')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();

            $table->index(['provider_iss', 'provider_sub', 'status']);
            $table->index(['status', 'expires_at']);
            $table->index('claim_token_hash');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('agent_registrations');
    }
};
