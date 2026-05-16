<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpException;

/**
 * Base Form Request with enhanced validation
 *
 * Provides common validation logic and authorization for all API requests.
 */
abstract class BaseFormRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    public function validated($key = null, $default = null)
    {
        if (! isset($this->validator)) {
            $validator = validator($this->all(), $this->rules(), $this->messages(), $this->attributes());

            return data_get($validator->validated(), $key, $default);
        }

        return parent::validated($key, $default);
    }

    /**
     * Get custom validation messages
     */
    public function messages(): array
    {
        return [
            'required' => 'The :attribute field is required.',
            'email' => 'The :attribute must be a valid email address.',
            'unique' => 'The :attribute has already been taken.',
            'exists' => 'The selected :attribute is invalid.',
            'integer' => 'The :attribute must be an integer.',
            'string' => 'The :attribute must be a string.',
            'array' => 'The :attribute must be an array.',
            'min' => [
                'string' => 'The :attribute must be at least :min characters.',
                'array' => 'The :attribute must have at least :min items.',
                'numeric' => 'The :attribute must be at least :min.',
            ],
            'max' => [
                'string' => 'The :attribute may not be greater than :max characters.',
                'array' => 'The :attribute may not have more than :max items.',
                'numeric' => 'The :attribute may not be greater than :max.',
            ],
            'in' => 'The selected :attribute is invalid.',
            'boolean' => 'The :attribute field must be true or false.',
            'date' => 'The :attribute is not a valid date.',
            'url' => 'The :attribute format is invalid.',
            'ip' => 'The :attribute must be a valid IP address.',
        ];
    }

    /**
     * Get custom attributes for validator error messages
     */
    public function attributes(): array
    {
        return [
            'name' => 'name',
            'email' => 'email address',
            'password' => 'password',
            'vmid' => 'container VMID',
            'hostname' => 'hostname',
            'status' => 'status',
        ];
    }

    /**
     * Handle a failed validation attempt.
     */
    protected function failedValidation(Validator $validator): void
    {
        $errors = $validator->errors()->toArray();

        throw new HttpException(
            response()->json([
                'error' => 'Validation failed',
                'message' => 'The given data was invalid.',
                'errors' => $this->formatErrors($errors),
            ], 422)
        );
    }

    /**
     * Format validation errors for consistent API response
     */
    protected function formatErrors(array $errors): array
    {
        $formatted = [];

        foreach ($errors as $field => $messages) {
            $formatted[$field] = is_array($messages) ? $messages[0] : $messages;
        }

        return $formatted;
    }

    /**
     * Prepare inputs for validation
     */
    protected function prepareForValidation(): void
    {
        // Sanitize inputs
        $this->sanitizeInputs();
    }

    /**
     * Sanitize request inputs
     */
    protected function sanitizeInputs(): void
    {
        $input = $this->all();

        // Trim string values
        $input = array_map(function ($value) {
            return is_string($value) ? trim($value) : $value;
        }, $input);

        // Convert empty strings to null
        $input = array_map(function ($value) {
            return $value === '' ? null : $value;
        }, $input);

        $this->merge($input);
    }

    /**
     * Get validation rules for pagination
     */
    protected function getPaginationRules(): array
    {
        return [
            'page' => 'nullable|integer|min:1',
            'per_page' => 'nullable|integer|min:1|max:100',
            'sort' => 'nullable|string|in:asc,desc',
            'sort_by' => 'nullable|string|alpha_dash',
        ];
    }

    /**
     * Get common validation rules for IDs
     */
    protected function getIdRules(): array
    {
        return [
            'id' => 'required|integer|min:1',
        ];
    }

    /**
     * Validate boolean fields
     */
    protected function validateBoolean(string $field): void
    {
        $this->merge([
            $field => $this->input($field) === '1'
                || $this->input($field) === 'true'
                || $this->input($field) === true,
        ]);
    }
}
