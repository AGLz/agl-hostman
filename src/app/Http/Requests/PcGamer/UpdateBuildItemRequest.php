<?php

declare(strict_types=1);

namespace App\Http\Requests\PcGamer;

use Illuminate\Foundation\Http\FormRequest;

class UpdateBuildItemRequest extends FormRequest
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
            'label' => ['sometimes', 'string', 'max:255'],
            'unit_cost_cents' => ['sometimes', 'integer', 'min:0'],
            'component_id' => ['nullable', 'integer', 'exists:pcg_components,id'],
            'offer_id' => ['nullable', 'integer', 'exists:pcg_telegram_offers,id'],
            'quantity' => ['sometimes', 'integer', 'min:1', 'max:99'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
