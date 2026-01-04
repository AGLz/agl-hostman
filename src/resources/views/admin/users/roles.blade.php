@extends('layouts.admin')

@section('title', 'Manage User Roles')

@section('content')
<div class="max-w-4xl mx-auto">
    <div class="flex justify-between items-center mb-6">
        <div>
            <h1 class="text-2xl font-bold text-gray-900">Manage Roles: {{ $user->name }}</h1>
            <p class="text-sm text-gray-500">{{ $user->email }}</p>
        </div>
        <div class="flex space-x-3">
            <a href="{{ route('admin.users.permissions', $user) }}"
               class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-2 px-4 rounded">
                Manage Permissions
            </a>
            <a href="{{ route('admin.users.access', $user) }}"
               class="bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded">
                View Access
            </a>
        </div>
    </div>

    <form action="{{ route('admin.users.roles.update', $user) }}" method="POST" class="bg-white shadow rounded-lg p-6">
        @csrf
        @method('PUT')

        <div class="mb-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Assign Roles</h3>
            <div class="space-y-3">
                @foreach($roles as $role)
                    <label class="flex items-center p-3 border border-gray-200 rounded hover:bg-gray-50">
                        <input type="checkbox"
                               name="roles[]"
                               value="{{ $role->id }}"
                               @if(in_array($role->id, $userRoleIds)) checked @endif
                               class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                        <div class="ml-3">
                            <span class="text-sm font-medium text-gray-900">{{ $role->name }}</span>
                            @if($role->is_system)
                                <span class="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                                    System
                                </span>
                            @endif
                            <p class="text-xs text-gray-500">{{ $role->description ?? 'No description' }}</p>
                        </div>
                    </label>
                @endforeach
            </div>
        </div>

        <div class="flex justify-end space-x-3">
            <a href="{{ route('admin.roles.index') }}"
               class="bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium py-2 px-4 rounded">
                Back to Roles
            </a>
            <button type="submit"
                    class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded">
                Update Roles
            </button>
        </div>
    </form>

    <!-- Current Roles -->
    <div class="mt-6 bg-white shadow rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Current Roles ({{ $user->roles->count() }})</h3>
        @if($user->roles->count() > 0)
            <div class="flex flex-wrap gap-2">
                @foreach($user->roles as $role)
                    <span class="inline-flex items-center px-3 py-1 rounded text-sm font-medium bg-gray-100 text-gray-800">
                        {{ $role->name }}
                        <form action="{{ route('admin.users.roles.remove', [$user, $role]) }}"
                              method="POST" class="inline ml-2">
                            @csrf
                            @method('DELETE')
                            <button type="submit"
                                    class="text-red-600 hover:text-red-900 ml-1"
                                    onclick="return confirm('Remove {{ $role->name }} role?')">
                                &times;
                            </button>
                        </form>
                    </span>
                @endforeach
            </div>
        @else
            <p class="text-sm text-gray-500">No roles assigned to this user.</p>
        @endif
    </div>
</div>
