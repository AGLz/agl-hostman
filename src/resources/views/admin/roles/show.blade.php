@extends('layouts.admin')

@section('title', 'Role: ' . $role->name)

@section('content')
<div class="max-w-6xl mx-auto">
    <div class="flex justify-between items-center mb-6">
        <div>
            <h1 class="text-2xl font-bold text-gray-900">{{ $role->name }}</h1>
            @if($role->is_system)
                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                    System Role
                </span>
            @endif
        </div>
        <div class="flex space-x-3">
            @can('edit-roles')
                <a href="{{ route('admin.roles.edit', $role) }}"
                   class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-2 px-4 rounded">
                    Edit Role
                </a>
            @endcan
            <a href="{{ route('admin.roles.index') }}"
               class="bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium py-2 px-4 rounded">
                Back to Roles
            </a>
        </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Role Details -->
        <div class="bg-white shadow rounded-lg p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">Role Details</h2>
            <dl class="space-y-3">
                <div class="flex justify-between">
                    <dt class="text-sm font-medium text-gray-500">Name</dt>
                    <dd class="text-sm text-gray-900">{{ $role->name }}</dd>
                </div>
                <div class="flex justify-between">
                    <dt class="text-sm font-medium text-gray-500">Description</dt>
                    <dd class="text-sm text-gray-900">{{ $role->description ?? '-' }}</dd>
                </div>
                <div class="flex justify-between">
                    <dt class="text-sm font-medium text-gray-500">System Role</dt>
                    <dd class="text-sm text-gray-900">
                        @if($role->is_system)
                            <span class="text-green-600">Yes</span>
                        @else
                            <span class="text-gray-400">No</span>
                        @endif
                    </dd>
                </div>
                <div class="flex justify-between">
                    <dt class="text-sm font-medium text-gray-500">Permissions Count</dt>
                    <dd class="text-sm text-gray-900">{{ $role->permissions->count() }}</dd>
                </div>
                <div class="flex justify-between">
                    <dt class="text-sm font-medium text-gray-500">Users Count</dt>
                    <dd class="text-sm text-gray-900">{{ $role->users->count() }}</dd>
                </div>
            </dl>
        </div>

        <!-- Permissions -->
        <div class="bg-white shadow rounded-lg p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">Permissions ({{ $role->permissions->count() }})</h2>
            @if($role->permissions->count() > 0)
                <div class="space-y-3">
                    @foreach($role->permissions->groupBy('module') as $module => $permissions)
                        <div>
                            <h4 class="text-xs font-semibold text-gray-500 uppercase mb-1">{{ $module }}</h4>
                            <div class="flex flex-wrap gap-1">
                                @foreach($permissions as $permission)
                                    <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                                        {{ $permission->name }}
                                    </span>
                                @endforeach
                            </div>
                        </div>
                    @endforeach
                </div>
            @else
                <p class="text-sm text-gray-500">No permissions assigned.</p>
            @endif
        </div>
    </div>

    <!-- Users with this role -->
    <div class="mt-6 bg-white shadow rounded-lg p-6">
        <h2 class="text-lg font-medium text-gray-900 mb-4">Users with this role ({{ $role->users->count() }})</h2>
        @if($role->users->count() > 0)
            <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Active</th>
                    </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                    @foreach($role->users as $user)
                        <tr>
                            <td class="px-4 py-2 text-sm text-gray-900">{{ $user->name }}</td>
                            <td class="px-4 py-2 text-sm text-gray-500">{{ $user->email }}</td>
                            <td class="px-4 py-2 text-sm">
                                @if($user->is_active)
                                    <span class="text-green-600">Yes</span>
                                @else
                                    <span class="text-red-600">No</span>
                                @endif
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        @else
            <p class="text-sm text-gray-500">No users assigned to this role.</p>
        @endif
    </div>
</div>
