<?php

namespace Tests;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;

class DatabaseTest extends TestCase
{
    public function test_mysql_connection()
    {
        $pdo = DB::connection()->getPdo();
        $this->assertNotNull($pdo);
        echo "MySQL: CONNECTED ✅\n";
    }

    public function test_redis_connection()
    {
        Cache::store('redis')->put('test', 'ok', 10);
        $value = Cache::store('redis')->get('test');
        $this->assertEquals('ok', $value);
        echo "Redis: CONNECTED ✅\n";
    }

    public function test_queue_redis_connection()
    {
        $connection = Queue::connection('redis');
        $this->assertNotNull($connection);
        echo "Queue (Redis): CONNECTED ✅\n";
    }
}
