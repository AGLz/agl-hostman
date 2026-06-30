<?php

declare(strict_types=1);

namespace App\Http\Requests\PcGamer;

use App\Enums\PcGamer\BuildStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class TransitionBuildStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'status' => ['required', Rule::enum(BuildStatus::class)],
            'notes' => ['nullable', 'string', 'max:1000'],
            'payload' => ['nullable', 'array'],
        ];
    }
}
