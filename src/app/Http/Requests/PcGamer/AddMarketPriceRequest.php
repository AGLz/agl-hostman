<?php

declare(strict_types=1);

namespace App\Http\Requests\PcGamer;

use Illuminate\Foundation\Http\FormRequest;

class AddMarketPriceRequest extends FormRequest
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
            'retailer_slug' => ['required', 'string', 'exists:pcg_retailers,slug'],
            'category_slug' => ['required', 'string', 'max:64'],
            'product_name' => ['required', 'string', 'max:240'],
            'price_cents' => ['required', 'integer', 'min:1'],
            'url' => ['nullable', 'url', 'max:2000'],
            'notes' => ['nullable', 'string', 'max:500'],
        ];
    }
}
