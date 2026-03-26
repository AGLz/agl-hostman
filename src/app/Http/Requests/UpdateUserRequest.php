<?php

declare(strict_types=1);

namespace App\Http\Requests;

/**
 * Update User Request
 *
 * Validation rules for updating user profiles.
 */
class UpdateUserRequest extends BaseFormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        // Users can update their own profile, or admins can update any user
        $userId = $this->route('user');
        $currentUser = auth()->user();

        return $currentUser && (
            $currentUser->id == $userId ||
            $currentUser->hasRole('admin')
        ) && $currentUser->isActive();
    }

    /**
     * Get validation rules
     */
    public function rules(): array
    {
        $userId = $this->route('user');

        return [
            'name' => 'nullable|string|max:255',
            'email' => 'nullable|email|max:255|unique:users,email,'.$userId,
            'avatar_url' => 'nullable|url|max:500',
            'is_active' => 'nullable|boolean',
            'role' => 'nullable|string|exists:roles,name',
            'location_ids' => 'nullable|array',
            'location_ids.*' => 'integer|exists:physical_locations,id',
            'notification_preferences' => 'nullable|array',
            'notification_preferences.email' => 'nullable|boolean',
            'notification_preferences.slack' => 'nullable|boolean',
            'notification_preferences.webhook' => 'nullable|url',
        ];
    }

    /**
     * Get custom messages for user validation
     */
    public function messages(): array
    {
        return array_merge(parent::messages(), [
            'email.unique' => 'This email address is already in use.',
            'avatar_url.url' => 'The avatar URL must be a valid URL.',
            'notification_preferences.webhook.url' => 'The webhook URL must be a valid URL.',
        ]);
    }
}
