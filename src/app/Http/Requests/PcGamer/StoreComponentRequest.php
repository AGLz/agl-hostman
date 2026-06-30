<?php

declare(strict_types=1);

namespace App\Http\Requests\PcGamer;

use Illuminate\Foundation\Http\FormRequest;

class StoreComponentRequest extends FormRequest
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
            'category_slug' => ['required', 'string', 'exists:pcg_component_categories,slug'],
            'model' => ['required', 'string', 'max:255'],
            'brand' => ['nullable', 'string', 'max:128'],
            'sku' => ['nullable', 'string', 'max:128'],
            'specs' => ['nullable', 'array'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
