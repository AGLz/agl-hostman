<?php

/**
 * config/app.php - Add this to the 'aliases' array
 *
 * Add the Input facade alias for backward compatibility
 * with legacy code using Input::get() instead of request()->input()
 */

return [

    // ... other config ...

    'aliases' => [
        // ... existing aliases ...

        // Add Input facade for backward compatibility
        'Input' => App\Helpers\Input::class,

        // ... rest of aliases ...
    ],

];
