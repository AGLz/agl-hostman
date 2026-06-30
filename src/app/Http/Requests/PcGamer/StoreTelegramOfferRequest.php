<?php

declare(strict_types=1);

namespace App\Http\Requests\PcGamer;

use Illuminate\Foundation\Http\FormRequest;

class StoreTelegramOfferRequest extends FormRequest
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
            'chat_key' => ['required', 'string', 'max:128'],
            'message_id' => ['required', 'integer', 'min:1'],
            'message_hash' => ['required', 'string', 'max:128'],
            'raw_text' => ['required', 'string', 'max:10000'],
            'posted_at' => ['nullable', 'date'],
            'source_title' => ['nullable', 'string', 'max:255'],
            'parsed' => ['required', 'array'],
            'parsed.product_name' => ['nullable', 'string', 'max:240'],
            'parsed.price_cents' => ['nullable', 'integer', 'min:0'],
            'parsed.currency' => ['nullable', 'string', 'max:8'],
            'parsed.url' => ['nullable', 'url', 'max:2000'],
            'parsed.matched_category_slug' => ['nullable', 'string', 'max:64'],
        ];
    }
}
