<?php

declare(strict_types=1);

namespace App\Http\Requests;

/**
 * Store Deployment Request
 *
 * Validation rules for triggering new deployments.
 */
class StoreDeploymentRequest extends BaseFormRequest
{
    /**
     * Get validation rules
     */
    public function rules(): array
    {
        return [
            'application_id' => 'required|integer|exists:dokploy_applications,id',
            'environment' => 'required|string|in:dev,qa,uat,production',
            'branch' => 'required|string|max:255|regex:/^[a-zA-Z0-9-_\/]+$/',
            'commit_hash' => 'nullable|string|max:40|regex:/^[a-fA-F0-9]+$/',
            'title' => 'nullable|string|max:255',
            'metadata' => 'nullable|array',
            'environment_variables' => 'nullable|array',
            'environment_variables.*.key' => 'required|string|max:100',
            'environment_variables.*.value' => 'nullable|string|max:10000',
            'deploy_on_push' => 'nullable|boolean',
        ];
    }

    /**
     * Get custom messages for deployment validation
     */
    public function messages(): array
    {
        return array_merge(parent::messages(), [
            'branch.regex' => 'The branch name may only contain letters, numbers, hyphens, underscores, and forward slashes.',
            'commit_hash.regex' => 'The commit hash must be a valid hexadecimal string.',
        ]);
    }
}
