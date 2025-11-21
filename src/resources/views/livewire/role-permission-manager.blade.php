<div>
    <!-- System Role Warning -->
    @if (in_array($role->name, ['super-admin', 'admin']))
        <div class="rounded-md bg-yellow-50 dark:bg-yellow-900/20 p-4 mb-4">
            <div class="flex">
                <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
                    </svg>
                </div>
                <div class="ml-3">
                    <h3 class="text-sm font-medium text-yellow-800 dark:text-yellow-300">
                        {{ __('System Role') }}
                    </h3>
                    <p class="mt-1 text-sm text-yellow-700 dark:text-yellow-400">
                        {{ __('This is a system role. Permissions cannot be modified.') }}
                    </p>
                </div>
            </div>
        </div>
    @endif

    <!-- Current Permissions Summary -->
    <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4 mb-4">
        <div class="flex items-center justify-between">
            <div>
                <p class="text-sm font-medium text-gray-900 dark:text-white">
                    {{ __('Current Permissions') }}
                </p>
                <p class="text-xs text-gray-500 dark:text-gray-400">
                    {{ count($selectedPermissions) }} {{ __('of') }} {{ \Spatie\Permission\Models\Permission::count() }} {{ __('selected') }}
                </p>
            </div>
            @if (!in_array($role->name, ['super-admin', 'admin']))
                <button wire:click="openModal" type="button"
                        class="inline-flex items-center px-3 py-2 border border-gray-300 dark:border-gray-600 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                    <svg class="-ml-0.5 mr-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                    </svg>
                    {{ __('Manage Permissions') }}
                </button>
            @endif
        </div>
    </div>

    <!-- Current Permissions Grid (Read-only) -->
    <div class="space-y-4">
        @foreach ($groupedPermissions as $group => $permissions)
            <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-4">
                <h4 class="text-sm font-medium text-gray-900 dark:text-white capitalize mb-3">
                    {{ $group }} {{ __('Permissions') }} ({{ $permissions->whereIn('name', $selectedPermissions)->count() }}/{{ $permissions->count() }})
                </h4>
                <div class="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3">
                    @foreach ($permissions as $permission)
                        <div class="flex items-center">
                            <div class="flex items-center h-5">
                                @if (in_array($permission->name, $selectedPermissions))
                                    <svg class="h-5 w-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                                    </svg>
                                @else
                                    <svg class="h-5 w-5 text-gray-300 dark:text-gray-600" fill="currentColor" viewBox="0 0 20 20">
                                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293z" clip-rule="evenodd"/>
                                    </svg>
                                @endif
                            </div>
                            <label class="ml-2 block text-sm text-gray-700 dark:text-gray-300">
                                {{ $permission->name }}
                            </label>
                        </div>
                    @endforeach
                </div>
            </div>
        @endforeach
    </div>

    <!-- Edit Permissions Modal -->
    @if ($showModal)
        <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
            <!-- Background Overlay -->
            <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
                <div wire:click="closeModal" class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true"></div>

                <!-- Modal Panel -->
                <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>
                <div class="inline-block align-bottom bg-white dark:bg-gray-800 rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full sm:p-6">
                    <div>
                        <div class="mt-3 text-center sm:mt-0 sm:text-left">
                            <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white mb-4" id="modal-title">
                                {{ __('Manage Permissions for :role', ['role' => $role->name]) }}
                            </h3>

                            <!-- Permission Groups -->
                            <div class="mt-4 max-h-96 overflow-y-auto space-y-4">
                                @foreach ($groupedPermissions as $group => $permissions)
                                    <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                        <div class="flex items-center justify-between mb-3">
                                            <h4 class="text-sm font-medium text-gray-900 dark:text-white capitalize">
                                                {{ $group }} {{ __('Permissions') }}
                                            </h4>
                                            <div class="flex space-x-2">
                                                <button type="button" wire:click="selectAllInGroup('{{ $group }}')"
                                                        class="text-xs text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300">
                                                    {{ __('Select All') }}
                                                </button>
                                                <span class="text-gray-300 dark:text-gray-600">|</span>
                                                <button type="button" wire:click="deselectAllInGroup('{{ $group }}')"
                                                        class="text-xs text-gray-600 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300">
                                                    {{ __('Deselect All') }}
                                                </button>
                                            </div>
                                        </div>
                                        <div class="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3">
                                            @foreach ($permissions as $permission)
                                                <div class="flex items-center">
                                                    <input type="checkbox"
                                                           wire:click="togglePermission('{{ $permission->name }}')"
                                                           @if (in_array($permission->name, $selectedPermissions)) checked @endif
                                                           id="permission_modal_{{ $permission->id }}"
                                                           class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-gray-600 rounded">
                                                    <label for="permission_modal_{{ $permission->id }}"
                                                           class="ml-2 block text-sm text-gray-700 dark:text-gray-300 cursor-pointer">
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

                    <!-- Modal Actions -->
                    <div class="mt-5 sm:mt-6 sm:grid sm:grid-cols-2 sm:gap-3 sm:grid-flow-row-dense">
                        <button wire:click="savePermissions" type="button"
                                class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-blue-600 text-base font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:col-start-2 sm:text-sm">
                            {{ __('Save Changes') }}
                        </button>
                        <button wire:click="closeModal" type="button"
                                class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 dark:border-gray-600 shadow-sm px-4 py-2 bg-white dark:bg-gray-700 text-base font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:mt-0 sm:col-start-1 sm:text-sm">
                            {{ __('Cancel') }}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    @endif
</div>
