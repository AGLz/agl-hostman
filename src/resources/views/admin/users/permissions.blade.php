@extends('layouts.admin')

@section('title', 'Manage User Permissions')

@section('content')
<div class="max-w-4xl mx-auto">
    <div class="flex justify-between items-center mb-6">
        <div>
            <h1 class="text-2xl font-bold text-gray-900">Direct Permissions: {{ $user->name }}</h1>
            <p class="text-sm text-gray-500">{{ $user->email }}</p>
        </div>
        <div class="flex space-x-3">
            <a href="{{ route('admin.users.roles.edit', $user) }}"
               class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-2 px-4 rounded">
                Manage Roles
            </a>
            <a href="{{ route('admin.users.access', $user) }}"
               class="bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded">
                View Access
            </a>
        </div>
    </div>

    <div class="bg-yellow-50 border border-yellow-200 text-yellow-700 px-4 py-3 rounded mb-6">
        <strong>Note:</strong> Direct permissions are granted in addition to permissions from roles.
        Use this for special permission overrides.
    </div>

    <form action="{{ route('admin.users.permissions.update', $user) }}" method="POST" class="bg-white shadow rounded-lg p-6">
        @csrf
        @method('PUT')

        <div class="mb-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Grant Direct Permissions</h3>
            @foreach($modules as $module)
                <div class="mb-4">
                    <h4 class="text-sm font-medium text-gray-700 uppercase mb-2">{{ $module }}</h4>
                    <div class="grid grid-cols-2 md:grid-cols-3 gap-2">
                        @foreach($permissions->where('module', $module) as $permission)
                            <label class="flex items-start">
                                <input type="checkbox"
                                       name="permissions[]"
                                       value="{{ $permission->id }}"
                                       @if(in_array($permission->id, $userPermissionIds)) checked @endif
                                       class="mt-1 h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                                <span class="ml-2 text-sm text-gray-600">{{ $permission->name }}</span>
                            </label>
                        @endforeach
                    </div>
                </div>
            @endforeach
        </div>

        <div class="flex justify-end space-x-3">
            <a href="{{ route('admin.permissions.index') }}"
               class="bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium py-2 px-4 rounded">
                Cancel
            </a>
            <button type="submit"
                    class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded">
                Update Permissions
            </button>
        </div>
    </form>

    <!-- Current Direct Permissions -->
    <div class="mt-6 bg-white shadow rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Current Direct Permissions ({{ $user->permissions->count() }})</h3>
        @if($user->permissions->count() > 0)
            <div class="flex flex-wrap gap-2">
                @foreach($user->permissions as $permission)
                    <span class="inline-flex items-center px-3 py-1 rounded text-sm font-medium bg-gray-100 text-gray-800">
                        {{ $permission->name }}
                        <form action="{{ route('admin.users.permissions.remove', [$user, $permission]) }}"
                              method="POST" class="inline ml-2">
                            @csrf
                            @method('DELETE')
                            <button type="submit"
                                    class="text-red-600 hover:text-red-900 ml-1"
                                    onclick="return confirm('Remove {{ $permission->name }} permission?')">
                                &times;
                            </button>
                        </form>
                    </span>
                @endforeach
            </div>
        @else
            <p class="text-sm text-gray-500">No direct permissions granted to this user.</p>
        @endif
    </div>
</div>
