<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Ensure roles and permissions exist first (only if not already seeded)
        if (\Spatie\Permission\Models\Permission::count() === 0) {
            $this->call([RolesAndPermissionsSeeder::class]);
        }

        $users = [
            [
                'name' => 'Andre Aguiar',
                'email' => 'andre@aglhost.com',
                'password' => 'AgL@2026Admin!',
                'role' => 'super-admin',
            ],
            [
                'name' => 'AGL Admin',
                'email' => 'admin@aglhost.com',
                'password' => 'Admin@123!',
                'role' => 'admin',
            ],
            [
                'name' => 'AGL Operator',
                'email' => 'operator@aglhost.com',
                'password' => 'Operator@123!',
                'role' => 'operator',
            ],
            [
                'name' => 'AGL Viewer',
                'email' => 'viewer@aglhost.com',
                'password' => 'Viewer@123!',
                'role' => 'viewer',
            ],
        ];

        foreach ($users as $userData) {
            $user = User::firstOrCreate(
                ['email' => $userData['email']],
                [
                    'name' => $userData['name'],
                    'password' => Hash::make($userData['password']),
                    'email_verified_at' => now(),
                    'is_active' => true,
                ]
            );

            // Assign role (roles already have permissions from RolesAndPermissionsSeeder)
            $user->assignRole($userData['role']);

            $this->command->info("✅ User created: {$userData['name']} ({$userData['email']})");
            $this->command->info("   Role: {$userData['role']}");
            $this->command->info("   Password: {$userData['password']}");
            $this->command->line('');
        }

        $this->command->info('🔐 Admin users seeded successfully!');
        $this->command->warn('⚠️  Change default passwords in production!');
    }
}
