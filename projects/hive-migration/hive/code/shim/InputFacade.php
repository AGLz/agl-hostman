<?php

namespace App\Helpers;

use Illuminate\Support\Facades\Facade;

/**
 * Input Facade Compatibility for Laravel 6+
 *
 * The Input facade was deprecated in Laravel 5.2 and removed in Laravel 6.0
 * This provides backward compatibility for legacy code using Input::get()
 *
 * Target: /var/www/fg_OLD2_NEW/app/Helpers/InputFacade.php
 * Critical For: 20+ controller methods across multiple controllers
 *
 * Register in config/app.php aliases array:
 * 'Input' => App\Helpers\Input::class,
 */
class Input extends Facade
{
    /**
     * Get the registered name of the component.
     */
    protected static function getFacadeAccessor(): string
    {
        return 'request';
    }

    /**
     * Get an input value from the request.
     *
     * @param string|null $key
     * @param mixed $default
     * @return mixed
     */
    public static function get($key = null, $default = null)
    {
        if (is_null($key)) {
            return static::all();
        }

        return static::$app['request']->input($key, $default);
    }

    /**
     * Get all input data from the request.
     *
     * @return array
     */
    public static function all(): array
    {
        return static::$app['request']->all();
    }

    /**
     * Get input only for specified keys.
     *
     * @param array|string $keys
     * @return array
     */
    public static function only($keys): array
    {
        return static::$app['request']->only($keys);
    }

    /**
     * Get input except for specified keys.
     *
     * @param array|string $keys
     * @return array
     */
    public static function except($keys): array
    {
        return static::$app['request']->except($keys);
    }

    /**
     * Check if input has a given key.
     *
     * @param string|array $key
     * @return bool
     */
    public static function has($key): bool
    {
        return static::$app['request']->has($key);
    }

    /**
     * Get old input data.
     *
     * @param string|null $key
     * @param mixed $default
     * @return mixed
     */
    public static function old($key = null, $default = null)
    {
        return static::$app['request']->old($key, $default);
    }
}
