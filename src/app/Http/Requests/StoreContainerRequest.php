<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Validation\Rule;

/**
 * Store Container Request
 *
 * Validation rules for creating new LXC containers.
 *
 * @package App\Http\Requests
 */
class StoreContainerRequest extends BaseFormRequest
{
    /**
     * Get validation rules
     *
     * @return array
     */
    public function rules(): array
    {
        return [
            'vmid' => 'required|integer|min:100|unique:lxc_containers,vmid',
            'name' => 'required|string|max:255|regex:/^[a-zA-Z0-9-_]+$/',
            'hostname' => 'nullable|string|max:255|regex:/^[a-zA-Z0-9.-]+$/',
            'proxmox_server_id' => 'required|integer|exists:proxmox_servers,id',
            'os_template' => 'nullable|string|max:255',
            'cores' => 'required|integer|min:1|max:16',
            'memory_mb' => 'required|integer|min:512|max:32768',
            'disk_gb' => 'required|integer|min:1|max:1000',
            'network_config' => 'nullable|array',
            'network_config.*.bridge' => 'nullable|string|max:100',
            'network_config.*.ip' => 'nullable|ip',
            'network_config.*.gateway' => 'nullable|ip',
            'metadata' => 'nullable|array',
            'description' => 'nullable|string|max:1000',
            'is_template' => 'nullable|boolean',
            'auto_start' => 'nullable|boolean',
        ];
    }

    /**
     * Get custom messages for container validation
     *
     * @return array
     */
    public function messages(): array
    {
        return array_merge(parent::messages(), [
            'vmid.unique' => 'A container with this VMID already exists.',
            'name.regex' => 'The name may only contain letters, numbers, hyphens, and underscores.',
            'hostname.regex' => 'The hostname may only contain letters, numbers, dots, and hyphens.',
            'cores.min' => 'At least 1 CPU core is required.',
            'cores.max' => 'Cannot exceed 16 CPU cores.',
            'memory_mb.min' => 'At least 512MB of memory is required.',
            'disk_gb.min' => 'At least 1GB of disk space is required.',
        ]);
    }
}
