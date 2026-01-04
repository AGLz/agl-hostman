@extends('layouts.admin')

@section('title', 'Roles Management')

@section('content')
<div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold text-gray-900">Roles Management</h1>
    @can('roles.create')
        <a href="{{ route('admin.roles.create') }}"
           class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded">
            Create Role
        </a>
    @endcan
</div>

<div class="bg-white shadow rounded-lg overflow-hidden">
    <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
            <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Name
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Description
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Permissions
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Users
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                </th>
            </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
            @foreach($roles as $role)
                <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap">
                        <div class="flex items-center">
                            <span class="text-sm font-medium text-gray-900">{{ $role->name }}</span>
                            @if($role->is_system)
                                <span class="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                                    System
                                </span>
                            @endif
                        </div>
                    </td>
                    <td class="px-6 py-4">
                        <span class="text-sm text-gray-500">{{ $role->description ?? '-' }}</span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                        <span class="text-sm text-gray-900">{{ $role->permissions_count }}</span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                        <span class="text-sm text-gray-900">{{ $role->users_count }}</span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                        <a href="{{ route('admin.roles.show', $role) }}"
                           class="text-blue-600 hover:text-blue-900 mr-3">View</a>
                        @can('roles.edit')
                            <a href="{{ route('admin.roles.edit', $role) }}"
                               class="text-indigo-600 hover:text-indigo-900 mr-3">Edit</a>
                        @endcan
                        @if(!$role->is_system)
                            @can('roles.delete')
                                <form action="{{ route('admin.roles.destroy', $role) }}"
                                      method="POST" class="inline"
                                      onsubmit="return confirm('Are you sure you want to delete this role?')">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" class="text-red-600 hover:text-red-900">Delete</button>
                                </form>
                            @endcan
                        @endif
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>

    @if($roles->hasPages())
        <div class="bg-white px-4 py-3 border-t border-gray-200 sm:px-6">
                    {{ $roles->appends(request()->query())->links() }}
                </div>
    @endif
</div>
