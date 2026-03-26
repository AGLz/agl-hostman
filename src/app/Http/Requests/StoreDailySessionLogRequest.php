<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreDailySessionLogRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'occurred_on' => ['required', 'date'],
            'title' => ['nullable', 'string', 'max:255'],
            'summary' => ['required', 'string', 'max:65535'],
            'topics' => ['nullable', 'string'],
            'project_tags' => ['nullable', 'string'],
            'source' => ['nullable', 'string', 'max:32'],
        ];
    }

    /**
     * @return array{topics: array<int, string>, project_tags: array<int, string>}
     */
    public function parsedTags(): array
    {
        $topics = $this->string('topics')->trim()->toString();
        $projects = $this->string('project_tags')->trim()->toString();

        return [
            'topics' => $topics === '' ? [] : array_values(array_filter(array_map('trim', preg_split('/[,;\n]+/', $topics) ?: []))),
            'project_tags' => $projects === '' ? [] : array_values(array_filter(array_map('trim', preg_split('/[,;\n]+/', $projects) ?: []))),
        ];
    }
}
