@extends('layouts.admin')

@section('title', 'User Access Summary')

@section('content')
<div class="max-w-6xl mx-auto">
    <div class="flex justify-between items-center mb-6">
        <div>
            <h1 class="text-2xl font-bold text-gray-900">Access Summary: {{ $user->name }}</h1>
            <p class="text-sm text-gray-500">{{ $user->email }}</p>
        </div>
        <div class="flex space-x-3">
            <a href="{{ route('admin.users.roles.edit', $user) }}"
               class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-2 px-4 rounded">
                Manage Roles
            </a>
            <a href="{{ route('admin.users.permissions.edit', $user) }}"
               class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded">
                Direct Permissions
            </a>
        </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- User Info -->
        <div class="bg-white shadow rounded-lg p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">User Information</h2>
            <dl class="space-y-3">
                <div class="flex justify-between">
                    <dt class="text-sm font-medium text-gray-500">Name</dt>
                    <dd class="text-sm text-gray-900">{{ $user->name }}</dd>
                </div>
                <div class="flex justify-between">
                    <dt class="text-sm font-medium text-gray-500">Email</dt>
                    <dd class="text-sm text-gray-900">{{ $user->email }}</dd>
                </div>
                <div class="flex justify-between">
                    <dt class="text-sm font-medium text-gray-500">Active</dt>
                    <dd class="text-sm text-gray-900">
                        @if($user->is_active)
                            <span class="text-green-600">Yes</span>
                        @else
                            <span class="text-red-600">No</span>
                        @endif
                    </dd>
                </div>
            </dl>
        </div>

        <!-- Roles -->
        <div class="bg-white shadow rounded-lg p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">Assigned Roles ({{ $user->roles->count() }})</h2>
            @if($user->roles->count() > 0)
                <div class="space-y-2">
                    @foreach($user->roles as $role)
                        <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                            <span class="text-sm font-medium text-gray-900">{{ $role->name }}</span>
                            @if($role->is_system)
                                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                                    System
                                </span>
                            @endif
                        </div>
                    @endforeach
                </div>
            @else
                <p class="text-sm text-gray-500">No roles assigned.</p>
            @endif
        </div>
    </div>

    <!-- All Permissions Grouped by Module -->
    <div class="mt-6 bg-white shadow rounded-lg p-6">
        <h2 class="text-lg font-medium text-gray-900 mb-4">
            All Effective Permissions ({{ $allPermissions->count() }})
        </h2>
        <p class="text-sm text-gray-500 mb-4">
            This includes permissions from assigned roles plus direct permissions.
        </p>

        @if($allPermissions->count() > 0)
            <div class="space-y-4">
                @foreach($permissionsByModule as $module => $permissions)
                    <div>
                        <h4 class="text-sm font-semibold text-gray-700 uppercase mb-2 flex items-center">
                            <span class="w-2 h-2 bg-blue-500 rounded-full mr-2"></span>
                            {{ $module }}
                            <span class="ml-2 text-xs font-normal text-gray-500">({{ $permissions->count() }})</span>
                        </h4>
                        <div class="flex flex-wrap gap-2 ml-4">
                            @foreach($permissions as $permission)
                                <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-green-100 text-green-800">
                                    {{ $permission->name }}
                                </span>
                            @endforeach
                        </div>
                    </div>
                @endforeach
            </div>
        @else
            <p class="text-sm text-gray-500">No permissions available.</p>
        @endif
    </div>
</div>
