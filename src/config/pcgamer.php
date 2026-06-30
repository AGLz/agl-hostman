<?php

return [

    'default_margin_percent' => (float) env('PCG_DEFAULT_MARGIN_PERCENT', 15),

    'market' => [
        'providers' => array_filter(array_map(
            trim(...),
            explode(',', (string) env('PCG_MARKET_FETCH_PROVIDERS', 'mercadolivre,pichau,aliexpress,4gamers'))
        )),
        'mercadolivre' => [
            'access_token' => env('MERCADOLIVRE_ACCESS_TOKEN'),
            'only_official' => filter_var(env('MERCADOLIVRE_ONLY_OFFICIAL', false), FILTER_VALIDATE_BOOL),
        ],
        'aliexpress' => [
            'app_key' => env('ALIEXPRESS_APP_KEY'),
            'app_secret' => env('ALIEXPRESS_APP_SECRET'),
            'tracking_id' => env('ALIEXPRESS_TRACKING_ID'),
            'ship_from' => env('ALIEXPRESS_SHIP_FROM', 'BR'),
        ],
    ],

    'telegram' => [
        'monitor_chats' => array_filter(array_map(
            trim(...),
            explode(',', (string) env('TELEGRAM_MONITOR_CHATS', '@mmpromo,@pcdofafapromo,@tecnoarthardware,@opczaopromocoes,@amandapromos'))
        )),
        'tme_sync_limit' => (int) env('TME_SYNC_LIMIT', 20),
        'validation' => [
            'max_age_hours' => (int) env('OFFER_VALIDATION_MAX_AGE_HOURS', 72),
            'revalidate_minutes' => (int) env('OFFER_REVALIDATE_MINUTES', 30),
            'batch' => (int) env('OFFER_VALIDATION_BATCH', 25),
            'price_tolerance_percent' => (float) env('OFFER_PRICE_TOLERANCE_PERCENT', 5),
        ],
    ],

    'queries' => [
        'processador' => 'processador amd ryzen am5',
        'motherboard' => 'placa mae am5 b650',
        'memoria_ddr5' => 'memoria ddr5 32gb',
        'nvme' => 'ssd nvme 1tb gen4',
        'placa_video' => 'placa de video rtx',
        'gabinete' => 'gabinete gamer mid tower',
        'fonte' => 'fonte 750w 80 plus gold',
        'water_cooler' => 'water cooler aio 240mm',
        'fan' => 'fan 120mm pwm',
        'suporte_vga' => 'suporte placa de video',
    ],

];
