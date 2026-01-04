@extends('layouts.admin')

@section('title', 'Create Permission')

@section('content')
<div class="max-w-2xl mx-auto">
    <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Create Permission</h1>
        <a href="{{ route('admin.permissions.index') }}"
           class="text-gray-600 hover:text-gray-900">
            Back to Permissions
        </a>
    </div>

    <form action="{{ route('admin.permissions.store') }}" method="POST" class="bg-white shadow rounded-lg p-6">
        @csrf

        <div class="grid grid-cols-1 gap-6 mb-6">
            <div>
                <label for="module" class="block text-sm font-medium text-gray-700">Module</label>
                <input type="text"
                       name="module"
                       id="module"
                       list="modules"
                       value="{{ old('module') }}"
                       required
                       class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-blue-500 focus:border-blue-500 sm:text-sm">
                <datalist id="modules">
                    @foreach($modules as $existingModule)
                        <option value="{{ $existingModule }}">
                    @endforeach
                    <option value="containers">
                    <option value="servers">
                    <option value="users">
                    <option value="monitoring">
                    <option value="deployments">
                    <option value="infrastructure">
                </datalist>
                <p class="mt-1 text-xs text-gray-500">e.g., containers, users, monitoring</p>
            </div>

            <div>
                <label for="name" class="block text-sm font-medium text-gray-700">Action</label>
                <input type="text"
                       name="name"
                       id="name"
                       list="actions"
                       value="{{ old('name') }}"
                       required
                       class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-blue-500 focus:border-blue-500 sm:text-sm">
                <datalist id="actions">
                    <option value="view">
                    <option value="create">
                    <option value="edit">
                    <option value="delete">
                    <option value="manage">
                    <option value="logs">
                </datalist>
                <p class="mt-1 text-xs text-gray-500">e.g., view, create, edit, delete</p>
            </div>

            <div>
                <label for="description" class="block text-sm font-medium text-gray-700">Description</label>
                <textarea name="description"
                          id="description"
                          rows="3"
                          class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-blue-500 focus:border-blue-500 sm:text-sm">{{ old('description') }}</textarea>
            </div>

            <div class="bg-gray-50 p-3 rounded">
                <p class="text-sm text-gray-600">
                    <strong>Preview:</strong>
                    <code class="bg-gray-100 px-2 py-1 rounded">
                        <span id="preview">module.action</span>
                    </code>
                </p>
            </div>
        </div>

        <div class="flex justify-end space-x-3">
            <a href="{{ route('admin.permissions.index') }}"
               class="bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium py-2 px-4 rounded">
                Cancel
            </a>
            <button type="submit"
                    class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded">
                Create Permission
            </button>
        </div>
    </form>
</div>

<script>
    const moduleInput = document.getElementById('module');
    const nameInput = document.getElementById('name');
    const preview = document.getElementById('preview');

    function updatePreview() {
        const module = moduleInput.value || 'module';
        const name = nameInput.value || 'action';
        preview.textContent = `${module}.${name}`;
    }

    moduleInput.addEventListener('input', updatePreview);
    nameInput.addEventListener('input', updatePreview);
</script>
