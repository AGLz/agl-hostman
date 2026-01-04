@extends('layouts.admin')

@section('title', 'Create Role')

@section('content')
<div class="max-w-4xl mx-auto">
    <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Create Role</h1>
        <a href="{{ route('admin.roles.index') }}"
           class="text-gray-600 hover:text-gray-900">
            Back to Roles
        </a>
    </div>

    <form action="{{ route('admin.roles.store') }}" method="POST" class="bg-white shadow rounded-lg p-6">
        @csrf

        <div class="grid grid-cols-1 gap-6 mb-6">
            <div>
                <label for="name" class="block text-sm font-medium text-gray-700">Role Name</label>
                <input type="text"
                       name="name"
                       id="name"
                       value="{{ old('name') }}"
                       required
                       class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-blue-500 focus:border-blue-500 sm:text-sm">
                <p class="mt-1 text-xs text-gray-500">e.g., manager, editor, viewer</p>
            </div>

            <div>
                <label for="description" class="block text-sm font-medium text-gray-700">Description</label>
                <textarea name="description"
                          id="description"
                          rows="3"
                          class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-blue-500 focus:border-blue-500 sm:text-sm">{{ old('description') }}</textarea>
            </div>
        </div>

        <div class="mb-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Permissions</h3>
            @foreach($modules as $module)
                <div class="mb-4">
                    <h4 class="text-sm font-medium text-gray-700 uppercase mb-2">{{ $module }}</h4>
                    <div class="grid grid-cols-2 md:grid-cols-3 gap-2">
                        @foreach($permissions->where('module', $module) as $permission)
                            <label class="flex items-start">
                                <input type="checkbox"
                                       name="permissions[]"
                                       value="{{ $permission->id }}"
                                       class="mt-1 h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                                <span class="ml-2 text-sm text-gray-600">{{ $permission->name }}</span>
                            </label>
                        @endforeach
                    </div>
                </div>
            @endforeach
        </div>

        <div class="flex justify-end space-x-3">
            <a href="{{ route('admin.roles.index') }}"
               class="bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium py-2 px-4 rounded">
                Cancel
            </a>
            <button type="submit"
                    class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded">
                Create Role
            </button>
        </div>
    </form>
</div>
