@extends('layouts.app')

@section('title', __('User Details') . ' - ' . $user->name)

@section('content')
<div class="py-6">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header with Actions -->
        <div class="md:flex md:items-center md:justify-between mb-6">
            <div class="flex-1 min-w-0">
                <div class="flex items-center">
                    <a href="{{ route('users.index') }}" class="mr-4 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
                        </svg>
                    </a>
                    <div>
                        <h2 class="text-2xl font-bold leading-7 text-gray-900 dark:text-white sm:text-3xl">
                            {{ $user->name }}
                        </h2>
                        <div class="mt-1 flex items-center space-x-2">
                            <!-- Status Badge -->
                            @if ($user->isActive())
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400">
                                    <svg class="-ml-0.5 mr-1.5 h-2 w-2 text-green-400" fill="currentColor" viewBox="0 0 8 8">
                                        <circle cx="4" cy="4" r="3"/>
                                    </svg>
                                    {{ __('Active') }}
                                </span>
                            @else
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400">
                                    <svg class="-ml-0.5 mr-1.5 h-2 w-2 text-red-400" fill="currentColor" viewBox="0 0 8 8">
                                        <circle cx="4" cy="4" r="3"/>
                                    </svg>
                                    {{ __('Inactive') }}
                                </span>
                            @endif

                            <!-- Role Badges -->
                            @foreach ($user->roles as $role)
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400">
                                    {{ $role->name }}
                                </span>
                            @endforeach
                        </div>
                    </div>
                </div>
            </div>
            <div class="mt-4 flex space-x-3 md:mt-0 md:ml-4">
                @can('edit-users')
                    <a href="{{ route('users.edit', $user) }}"
                       class="inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                        <svg class="-ml-1 mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                        </svg>
                        {{ __('Edit') }}
                    </a>
                @endcan

                @livewire('user-quick-actions', ['user' => $user])
            </div>
        </div>

        <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
            <!-- Main Content (Left Column - 2/3 width) -->
            <div class="lg:col-span-2 space-y-6">
                <!-- User Information Card -->
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg">
                    <div class="px-4 py-5 sm:p-6">
                        <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white mb-4">
                            {{ __('User Information') }}
                        </h3>
                        <dl class="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Email') }}</dt>
                                <dd class="mt-1 text-sm text-gray-900 dark:text-white">{{ $user->email }}</dd>
                            </div>
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Last Login') }}</dt>
                                <dd class="mt-1 text-sm text-gray-900 dark:text-white">
                                    @if ($user->last_login_at)
                                        {{ $user->last_login_at->diffForHumans() }}
                                        <span class="text-gray-500 dark:text-gray-400 text-xs">
                                            ({{ $user->last_login_at->format('Y-m-d H:i:s') }})
                                        </span>
                                    @else
                                        <span class="text-gray-500 dark:text-gray-400">{{ __('Never') }}</span>
                                    @endif
                                </dd>
                            </div>
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Created At') }}</dt>
                                <dd class="mt-1 text-sm text-gray-900 dark:text-white">
                                    {{ $user->created_at->format('Y-m-d H:i:s') }}
                                    <span class="text-gray-500 dark:text-gray-400 text-xs">({{ $user->created_at->diffForHumans() }})</span>
                                </dd>
                            </div>
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Updated At') }}</dt>
                                <dd class="mt-1 text-sm text-gray-900 dark:text-white">
                                    {{ $user->updated_at->format('Y-m-d H:i:s') }}
                                    <span class="text-gray-500 dark:text-gray-400 text-xs">({{ $user->updated_at->diffForHumans() }})</span>
                                </dd>
                            </div>
                        </dl>
                    </div>
                </div>

                <!-- Physical Locations Card -->
                @if ($user->physicalLocations && $user->physicalLocations->isNotEmpty())
                    <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg">
                        <div class="px-4 py-5 sm:p-6">
                            <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white mb-4">
                                {{ __('Physical Locations') }}
                            </h3>
                            <ul class="divide-y divide-gray-200 dark:divide-gray-700">
                                @foreach ($user->physicalLocations as $location)
                                    <li class="py-3 flex items-center justify-between">
                                        <div class="flex items-center">
                                            <svg class="h-5 w-5 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                                            </svg>
                                            <span class="text-sm text-gray-900 dark:text-white">
                                                {{ $location->name }} ({{ $location->code }})
                                            </span>
                                        </div>
                                    </li>
                                @endforeach
                            </ul>
                        </div>
                    </div>
                @endif

                <!-- Activity Log -->
                @can('view-audit-logs')
                    <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg">
                        <div class="px-4 py-5 sm:p-6">
                            <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white mb-4">
                                {{ __('Recent Activity') }}
                            </h3>
                            @livewire('user-activity-log', ['user' => $user])
                        </div>
                    </div>
                @endcan
            </div>

            <!-- Sidebar (Right Column - 1/3 width) -->
            <div class="space-y-6">
                <!-- Roles Card -->
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg">
                    <div class="px-4 py-5 sm:p-6">
                        <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white mb-4">
                            {{ __('Roles & Permissions') }}
                        </h3>
                        @livewire('user-role-manager', ['user' => $user])
                    </div>
                </div>

                <!-- Statistics Card -->
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg">
                    <div class="px-4 py-5 sm:p-6">
                        <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white mb-4">
                            {{ __('Statistics') }}
                        </h3>
                        <dl class="space-y-4">
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Total Roles') }}</dt>
                                <dd class="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                                    {{ $user->roles->count() }}
                                </dd>
                            </div>
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Total Permissions') }}</dt>
                                <dd class="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                                    {{ $user->getAllPermissions()->count() }}
                                </dd>
                            </div>
                            <div>
                                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Account Age') }}</dt>
                                <dd class="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                                    {{ $user->created_at->diffInDays(now()) }} {{ __('days') }}
                                </dd>
                            </div>
                        </dl>
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
    Livewire.on('user-updated', event => {
        console.log('User updated:', event);
        // Optionally reload the page or show a notification
    });

    Livewire.on('role-assigned', event => {
        console.log('Role assigned:', event);
    });

    Livewire.on('role-removed', event => {
        console.log('Role removed:', event);
    });
</script>
@endpush
