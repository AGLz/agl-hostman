<?php

declare(strict_types=1);

return [

    /*
    |--------------------------------------------------------------------------
    | API key via query string
    |--------------------------------------------------------------------------
    |
    | Query parameters leak keys into access logs and Referer headers.
    | Disabled by default outside local; use X-API-Key or Authorization header.
    |
    */

    'allow_query_api_key' => env('ALLOW_QUERY_API_KEY', env('APP_ENV') === 'local'),

];
