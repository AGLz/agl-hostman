<?php

declare(strict_types=1);

use App\Services\Deployment\PromotionApprovalService;
use App\Services\Deployment\PromotionWorkflowService;

test('promotion workflow services resolve without circular dependency', function () {
    $approval = $this->app->make(PromotionApprovalService::class);
    $workflow = $this->app->make(PromotionWorkflowService::class);

    expect($approval)->toBeInstanceOf(PromotionApprovalService::class)
        ->and($workflow)->toBeInstanceOf(PromotionWorkflowService::class);
});
