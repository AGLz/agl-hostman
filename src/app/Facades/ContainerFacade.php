<?php

namespace App\Facades;

use Illuminate\Support\Facades\Facade;

/**
 * @method static \App\Services\Container\ContainerManagementService create(array $data)
 * @method static \App\Services\Container\ContainerManagementService clone(int $sourceVmid, array $options)
 * @method static \App\Services\Container\ContainerManagementService migrate(int $containerId, array $options)
 * @method static \App\Services\Container\ContainerManagementService backup(int $containerId, array $options)
 * @method static \App\Services\Container\ContainerManagementService snapshot(int $containerId, array $options)
 * @method static \Illuminate\Support\Collection list(array $filters = [])
 * @method static \App\Models\LxcContainer find(int $id)
 * @method static bool delete(int $id)
 * @method static array getStatus(int $id)
 * @method static array getMetrics(int $id)
 */
class ContainerFacade extends Facade
{
    /**
     * Get the registered name of the component.
     *
     * @return string
     */
    protected static function getFacadeAccessor(): string
    {
        return 'container';
    }
}