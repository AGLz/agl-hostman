<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'Admin') - {{ config('app.name') }}</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50">
    <nav class="bg-gray-800 border-b border-gray-700">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex justify-between h-16">
                <div class="flex items-center">
                    <h1 class="text-white text-lg font-semibold">AGL Admin</h1>
                    <div class="hidden md:ml-10 md:flex md:space-x-8">
                        <a href="{{ route('admin.roles.index') }}" class="text-gray-300 hover:text-white px-3 py-2 text-sm font-medium">Roles</a>
                        <a href="{{ route('admin.permissions.index') }}" class="text-gray-300 hover:text-white px-3 py-2 text-sm font-medium">Permissions</a>
                        <a href="{{ route('admin.users.roles') }}" class="text-gray-300 hover:text-white px-3 py-2 text-sm font-medium">Users</a>
                    </div>
                </div>
                <div class="flex items-center">
                    <span class="text-gray-300 text-sm">{{ Auth::user()->name }}</span>
                </div>
            </div>
        </div>
    </nav>

    <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        @if(session('success'))
            <div class="mb-4 bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded">
                {{ session('success') }}
            </div>
        @endif

        @if(session('error'))
            <div class="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
                {{ session('error') }}
            </div>
        @endif

        @if($errors->any())
            <div class="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
                <ul class="list-disc list-inside">
                    @foreach($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        @yield('content')
    </main>
</body>
</html>
