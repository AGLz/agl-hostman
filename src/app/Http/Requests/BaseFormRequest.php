<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpException;
use Illuminate\Support\Facades\Auth;

/**
 * Base Form Request with enhanced validation
 *
 * Provides common validation logic and authorization for all API requests.
 *
 * @package App\Http\Requests
 */
abstract class BaseFormRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     *
     * @return bool
     */
    public function authorize(): bool
    {
        // Default authorization logic
        // Override in child classes for specific requirements
        return Auth::check() && Auth::user()->isActive();
    }

    /**
     * Get custom validation messages
     *
     * @return array
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
     *
     * @return array
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
     *
     * @param  \Illuminate\Contracts\Validation\Validator  $validator
     * @return void
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
     *
     * @param array $errors
     * @return array
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
     *
     * @return void
     */
    protected function prepareForValidation(): void
    {
        // Sanitize inputs
        $this->sanitizeInputs();
    }

    /**
     * Sanitize request inputs
     *
     * @return void
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
     *
     * @return array
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
     *
     * @return array
     */
    protected function getIdRules(): array
    {
        return [
            'id' => 'required|integer|min:1',
        ];
    }

    /**
     * Validate boolean fields
     *
     * @param string $field
     * @return void
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
