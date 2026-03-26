<?php

namespace App\Http\Requests;

use App\Models\DailySessionLog;

class UpdateDailySessionLogRequest extends StoreDailySessionLogRequest
{
    public function authorize(): bool
    {
        /** @var DailySessionLog|null $log */
        $log = $this->route('daily_memory');

        return $log !== null
            && $this->user() !== null
            && $this->user()->id === $log->user_id;
    }
}
