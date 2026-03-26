<?php

declare(strict_types=1);

namespace App\Http\Requests;

/**
 * Update Container Request
 *
 * Validation rules for updating existing LXC containers.
 */
class UpdateContainerRequest extends BaseFormRequest
{
    /**
     * Get validation rules
     */
    public function rules(): array
    {
        $containerId = $this->route('container');

        return [
            'name' => 'nullable|string|max:255|regex:/^[a-zA-Z0-9-_]+$/',
            'hostname' => 'nullable|string|max:255|regex:/^[a-zA-Z0-9.-]+$/',
            'status' => 'nullable|in:running,stopped,creating,deleting',
            'cores' => 'nullable|integer|min:1|max:16',
            'memory_mb' => 'nullable|integer|min:512|max:32768',
            'disk_gb' => 'nullable|integer|min:1|max:1000',
            'network_config' => 'nullable|array',
            'metadata' => 'nullable|array',
            'description' => 'nullable|string|max:1000',
            'is_template' => 'nullable|boolean',
            'auto_start' => 'nullable|boolean',
        ];
    }
}
