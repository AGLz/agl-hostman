@extends('layouts.app')

@section('title', __('Role Details') . ' - ' . $role->name)

@section('content')
<div class="py-6">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header with Actions -->
        <div class="md:flex md:items-center md:justify-between mb-6">
            <div class="flex-1 min-w-0">
                <div class="flex items-center">
                    <a href="{{ route('roles.index') }}" class="mr-4 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
                        </svg>
                    </a>
                    <div>
                        <h2 class="text-2xl font-bold leading-7 text-gray-900 dark:text-white sm:text-3xl">
                            {{ $role->name }}
                        </h2>
                        <div class="mt-1 flex items-center space-x-2">
                            @if (in_array($role->name, ['super-admin', 'admin', 'operator', 'analyst', 'viewer']))
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-400">
                                    <svg class="-ml-0.5 mr-1.5 h-2 w-2 text-purple-400" fill="currentColor" viewBox="0 0 8 8">
                                        <circle cx="4" cy="4" r="3"/>
                                    </svg>
                                    {{ __('System Role') }}
                                </span>
                            @else
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300">
                                    {{ __('Custom Role') }}
                                </span>
                            @endif
                        </div>
                    </div>
                </div>
            </div>
            <div class="mt-4 flex space-x-3 md:mt-0 md:ml-4">
                @can('edit-roles')
                    @if (!in_array($role->name, ['super-admin', 'admin']))
                        <a href="{{ route('roles.edit', $role) }}"
                           class="inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                            <svg class="-ml-1 mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                            </svg>
                            {{ __('Edit') }}
                        </a>
                    @endif
                @endcan

                @can('delete-roles')
                    @if (!in_array($role->name, ['super-admin', 'admin', 'operator', 'analyst', 'viewer']))
                        <form action="{{ route('roles.destroy', $role) }}" method="POST"
                              onsubmit="return confirm('{{ __('Are you sure you want to delete this role?') }}')">
                            @csrf
                            @method('DELETE')
                            <button type="submit"
                                    class="inline-flex items-center px-4 py-2 border border-red-300 dark:border-red-600 rounded-md shadow-sm text-sm font-medium text-red-700 dark:text-red-400 bg-white dark:bg-gray-700 hover:bg-red-50 dark:hover:bg-red-900/20 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500">
                                <svg class="-ml-1 mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                                </svg>
                                {{ __('Delete') }}
                            </button>
                        </form>
                    @endif
                @endcan
            </div>
        </div>

        <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
            <!-- Main Content (Left Column - 2/3 width) -->
            <div class="lg:col-span-2 space-y-6">
                <!-- Role Information Card -->
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg">
                    <div class="px-4 py-5 sm:p-6">
                        <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white mb-4">
                            {{ __('Role Information') }}
                        </h3>
                        <dl class="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Role Name') }}</dt>
                                <dd class="mt-1 text-sm text-gray-900 dark:text-white font-mono">{{ $role->name }}</dd>
                            </div>
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Guard Name') }}</dt>
                                <dd class="mt-1 text-sm text-gray-900 dark:text-white font-mono">{{ $role->guard_name }}</dd>
                            </div>
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Total Users') }}</dt>
                                <dd class="mt-1 text-sm text-gray-900 dark:text-white">{{ $role->users->count() }}</dd>
                            </div>
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Total Permissions') }}</dt>
                                <dd class="mt-1 text-sm text-gray-900 dark:text-white">{{ $role->permissions->count() }}</dd>
                            </div>
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Created At') }}</dt>
                                <dd class="mt-1 text-sm text-gray-900 dark:text-white">
                                    {{ $role->created_at->format('Y-m-d H:i:s') }}
                                    <span class="text-gray-500 dark:text-gray-400 text-xs">({{ $role->created_at->diffForHumans() }})</span>
                                </dd>
                            </div>
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Updated At') }}</dt>
                                <dd class="mt-1 text-sm text-gray-900 dark:text-white">
                                    {{ $role->updated_at->format('Y-m-d H:i:s') }}
                                    <span class="text-gray-500 dark:text-gray-400 text-xs">({{ $role->updated_at->diffForHumans() }})</span>
                                </dd>
                            </div>
                        </dl>
                    </div>
                </div>

                <!-- Permissions Management -->
                @can('assign-permissions')
                    <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg">
                        <div class="px-4 py-5 sm:p-6">
                            <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white mb-4">
                                {{ __('Manage Permissions') }}
                            </h3>
                            @livewire('role-permission-manager', ['role' => $role])
                        </div>
                    </div>
                @endcan
            </div>

            <!-- Sidebar (Right Column - 1/3 width) -->
            <div class="space-y-6">
                <!-- Statistics Card -->
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg">
                    <div class="px-4 py-5 sm:p-6">
                        <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white mb-4">
                            {{ __('Statistics') }}
                        </h3>
                        <dl class="space-y-4">
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Active Users') }}</dt>
                                <dd class="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                                    {{ $role->users()->where('is_active', true)->count() }}
                                </dd>
                            </div>
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Inactive Users') }}</dt>
                                <dd class="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                                    {{ $role->users()->where('is_active', false)->count() }}
                                </dd>
                            </div>
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Permission Coverage') }}</dt>
                                <dd class="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                                    {{ round(($role->permissions->count() / \Spatie\Permission\Models\Permission::count()) * 100) }}%
                                </dd>
                            </div>
                        </dl>
                    </div>
                </div>

                <!-- Users with this Role -->
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg">
                    <div class="px-4 py-5 sm:p-6">
                        <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white mb-4">
                            {{ __('Users with this Role') }}
                        </h3>
                        @livewire('role-users-list', ['role' => $role])
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection

@push('scripts')
<script>
    // Listen for Livewire events
    Livewire.on('permissions-updated', event => {
        console.log('Permissions updated:', event);
    });
</script>
@endpush
