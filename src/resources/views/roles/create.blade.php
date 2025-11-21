@extends('layouts.app')

@section('title', __('Create Role'))

@section('content')
<div class="py-6">
    <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="mb-6">
            <div class="flex items-center mb-4">
                <a href="{{ route('roles.index') }}" class="mr-4 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
                    </svg>
                </a>
                <div>
                    <h2 class="text-2xl font-bold leading-7 text-gray-900 dark:text-white sm:text-3xl">
                        {{ __('Create New Role') }}
                    </h2>
                    <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                        {{ __('Create a custom role with specific permissions') }}
                    </p>
                </div>
            </div>
        </div>

        <!-- Form Card -->
        <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg">
            <form action="{{ route('roles.store') }}" method="POST" class="px-4 py-5 sm:p-6">
                @csrf

                <!-- Error Messages -->
                @if ($errors->any())
                    <div class="mb-6 rounded-md bg-red-50 dark:bg-red-900/20 p-4">
                        <div class="flex">
                            <div class="flex-shrink-0">
                                <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
                                </svg>
                            </div>
                            <div class="ml-3">
                                <h3 class="text-sm font-medium text-red-800 dark:text-red-300">
                                    {{ __('There were errors with your submission') }}
                                </h3>
                                <div class="mt-2 text-sm text-red-700 dark:text-red-400">
                                    <ul class="list-disc space-y-1 pl-5">
                                        @foreach ($errors->all() as $error)
                                            <li>{{ $error }}</li>
                                        @endforeach
                                    </ul>
                                </div>
                            </div>
                        </div>
                    </div>
                @endif

                <div class="space-y-6">
                    <!-- Role Name -->
                    <div>
                        <label for="name" class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                            {{ __('Role Name') }} <span class="text-red-500">*</span>
                        </label>
                        <input type="text" name="name" id="name" value="{{ old('name') }}" required
                               class="mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm dark:bg-gray-700 dark:text-white"
                               placeholder="e.g., content-manager">
                        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                            {{ __('Use lowercase with hyphens (e.g., "content-manager", "api-user")') }}
                        </p>
                    </div>

                    <!-- Permissions Selection -->
                    <div class="border-t border-gray-200 dark:border-gray-700 pt-6">
                        <h3 class="text-base font-medium text-gray-900 dark:text-white mb-4">
                            {{ __('Assign Permissions') }}
                        </h3>
                        <p class="text-sm text-gray-500 dark:text-gray-400 mb-4">
                            {{ __('Select the permissions this role should have') }}
                        </p>

                        @php
                            $groupedPermissions = \Spatie\Permission\Models\Permission::orderBy('name')->get()->groupBy(function ($permission) {
                                $parts = explode('-', $permission->name);
                                return $parts[0] ?? 'other';
                            });
                        @endphp

                        <div class="space-y-4">
                            @foreach ($groupedPermissions as $group => $permissions)
                                <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                    <div class="flex items-center justify-between mb-3">
                                        <h4 class="text-sm font-medium text-gray-900 dark:text-white capitalize">
                                            {{ $group }} {{ __('Permissions') }}
                                        </h4>
                                        <div class="flex space-x-2">
                                            <button type="button"
                                                    onclick="selectAllInGroup('{{ $group }}')"
                                                    class="text-xs text-blue-600 hover:text-blue-700 dark:text-blue-400">
                                                {{ __('Select All') }}
                                            </button>
                                            <span class="text-gray-400">|</span>
                                            <button type="button"
                                                    onclick="deselectAllInGroup('{{ $group }}')"
                                                    class="text-xs text-gray-600 hover:text-gray-700 dark:text-gray-400">
                                                {{ __('Deselect All') }}
                                            </button>
                                        </div>
                                    </div>
                                    <div class="grid grid-cols-1 gap-2 sm:grid-cols-2">
                                        @foreach ($permissions as $permission)
                                            <div class="flex items-center">
                                                <input id="permission_{{ $permission->id }}"
                                                       name="permissions[]"
                                                       type="checkbox"
                                                       value="{{ $permission->name }}"
                                                       {{ in_array($permission->name, old('permissions', [])) ? 'checked' : '' }}
                                                       data-group="{{ $group }}"
                                                       class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-gray-600 rounded dark:bg-gray-600">
                                                <label for="permission_{{ $permission->id }}"
                                                       class="ml-2 block text-sm text-gray-700 dark:text-gray-300">
                                                    {{ $permission->name }}
                                                </label>
                                            </div>
                                        @endforeach
                                    </div>
                                </div>
                            @endforeach
                        </div>
                    </div>
                </div>

                <!-- Action Buttons -->
                <div class="mt-6 flex items-center justify-end space-x-3 border-t border-gray-200 dark:border-gray-700 pt-6">
                    <a href="{{ route('roles.index') }}"
                       class="inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 shadow-sm text-sm font-medium rounded-md text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                        {{ __('Cancel') }}
                    </a>
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                        <svg class="-ml-1 mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                        </svg>
                        {{ __('Create Role') }}
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

@push('scripts')
<script>
    function selectAllInGroup(group) {
        document.querySelectorAll(`input[data-group="${group}"]`).forEach(checkbox => {
            checkbox.checked = true;
        });
    }

    function deselectAllInGroup(group) {
        document.querySelectorAll(`input[data-group="${group}"]`).forEach(checkbox => {
            checkbox.checked = false;
        });
    }
</script>
@endpush
@endsection
