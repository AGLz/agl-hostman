<?php

declare(strict_types=1);

namespace Tests\Unit\Requests;

use App\Http\Requests\StoreContainerRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Validator;
use Tests\TestCase;

/**
 * Store Container Request Test
 *
 * Tests for the StoreContainerRequest form request.
 */
class StoreContainerRequestTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->user = User::factory()->create();
        $this->user->givePermissionTo('create containers');
    }

    /**
     * Test authorized user can create container
     */
    public function test_authorized_user_can_create_container(): void
    {
        $request = new StoreContainerRequest;
        $request->setUserResolver(fn () => $this->user);

        $this->assertTrue($request->authorize());
    }

    /**
     * Test unauthorized user cannot create container
     */
    public function test_unauthorized_user_cannot_create_container(): void
    {
        $user = User::factory()->create();
        $user->revokePermissionTo('create containers');

        $request = new StoreContainerRequest;
        $request->setUserResolver(fn () => $user);

        $this->assertFalse($request->authorize());
    }

    /**
     * Test validation rules for container creation
     */
    public function test_validation_rules(): void
    {
        $rules = (new StoreContainerRequest)->rules();

        $this->assertArrayHasKey('vmid', $rules);
        $this->assertArrayHasKey('name', $rules);
        $this->assertArrayHasKey('hostname', $rules);
        $this->assertArrayHasKey('cores', $rules);
        $this->assertArrayHasKey('memory_mb', $rules);
        $this->assertArrayHasKey('disk_gb', $rules);
        $this->assertArrayHasKey('ip_address', $rules);
        $this->assertArrayHasKey('template_id', $rules);
        $this->assertArrayHasKey('proxmox_server_id', $rules);
    }

    /**
     * Test valid container data passes validation
     */
    public function test_valid_data_passes_validation(): void
    {
        $data = [
            'vmid' => 100,
            'name' => 'test-container',
            'hostname' => 'test01.example.com',
            'cores' => 2,
            'memory_mb' => 2048,
            'disk_gb' => 50,
            'ip_address' => '192.168.1.100',
            'template_id' => 1,
            'proxmox_server_id' => 1,
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertFalse($validator->fails());
    }

    /**
     * Test vmid is required
     */
    public function test_vmid_is_required(): void
    {
        $data = [
            'name' => 'test-container',
            'cores' => 2,
            'memory_mb' => 2048,
            'disk_gb' => 50,
            'template_id' => 1,
            'proxmox_server_id' => 1,
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertTrue($validator->fails());
        $this->assertArrayHasKey('vmid', $validator->errors()->toArray());
    }

    /**
     * Test vmid must be integer
     */
    public function test_vmid_must_be_integer(): void
    {
        $data = [
            'vmid' => 'not-an-integer',
            'name' => 'test-container',
            'cores' => 2,
            'memory_mb' => 2048,
            'disk_gb' => 50,
            'template_id' => 1,
            'proxmox_server_id' => 1,
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertTrue($validator->fails());
        $this->assertArrayHasKey('vmid', $validator->errors()->toArray());
    }

    /**
     * Test vmid must be at least 100
     */
    public function test_vmid_minimum_value(): void
    {
        $data = [
            'vmid' => 99,
            'name' => 'test-container',
            'cores' => 2,
            'memory_mb' => 2048,
            'disk_gb' => 50,
            'template_id' => 1,
            'proxmox_server_id' => 1,
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertTrue($validator->fails());
        $this->assertArrayHasKey('vmid', $validator->errors()->toArray());
    }

    /**
     * Test vmid maximum value
     */
    public function test_vmid_maximum_value(): void
    {
        $data = [
            'vmid' => 1000000000,
            'name' => 'test-container',
            'cores' => 2,
            'memory_mb' => 2048,
            'disk_gb' => 50,
            'template_id' => 1,
            'proxmox_server_id' => 1,
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertTrue($validator->fails());
        $this->assertArrayHasKey('vmid', $validator->errors()->toArray());
    }

    /**
     * Test name is required
     */
    public function test_name_is_required(): void
    {
        $data = [
            'vmid' => 100,
            'cores' => 2,
            'memory_mb' => 2048,
            'disk_gb' => 50,
            'template_id' => 1,
            'proxmox_server_id' => 1,
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertTrue($validator->fails());
        $this->assertArrayHasKey('name', $validator->errors()->toArray());
    }

    /**
     * Test name must be string
     */
    public function test_name_must_be_string(): void
    {
        $data = [
            'vmid' => 100,
            'name' => 123,
            'cores' => 2,
            'memory_mb' => 2048,
            'disk_gb' => 50,
            'template_id' => 1,
            'proxmox_server_id' => 1,
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertTrue($validator->fails());
        $this->assertArrayHasKey('name', $validator->errors()->toArray());
    }

    /**
     * Test name maximum length
     */
    public function test_name_maximum_length(): void
    {
        $data = [
            'vmid' => 100,
            'name' => str_repeat('a', 256),
            'cores' => 2,
            'memory_mb' => 2048,
            'disk_gb' => 50,
            'template_id' => 1,
            'proxmox_server_id' => 1,
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertTrue($validator->fails());
        $this->assertArrayHasKey('name', $validator->errors()->toArray());
    }

    /**
     * Test name regex validation
     */
    public function test_name_regex_validation(): void
    {
        $invalidNames = [
            'invalid name', // spaces
            'invalid@name', // special chars
            'invalid/name', // slash
        ];

        foreach ($invalidNames as $name) {
            $data = [
                'vmid' => 100,
                'name' => $name,
                'cores' => 2,
                'memory_mb' => 2048,
                'disk_gb' => 50,
                'template_id' => 1,
                'proxmox_server_id' => 1,
            ];

            $validator = Validator::make($data, (new StoreContainerRequest)->rules());

            $this->assertTrue($validator->fails(), "Name '{$name}' should fail validation");
        }
    }

    /**
     * Test cores validation
     */
    public function test_cores_validation(): void
    {
        $data = [
            'vmid' => 100,
            'name' => 'test-container',
            'cores' => 0, // Too low
            'memory_mb' => 2048,
            'disk_gb' => 50,
            'template_id' => 1,
            'proxmox_server_id' => 1,
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertTrue($validator->fails());
        $this->assertArrayHasKey('cores', $validator->errors()->toArray());
    }

    /**
     * Test memory_mb validation
     */
    public function test_memory_mb_validation(): void
    {
        $data = [
            'vmid' => 100,
            'name' => 'test-container',
            'cores' => 2,
            'memory_mb' => 256, // Too low
            'disk_gb' => 50,
            'template_id' => 1,
            'proxmox_server_id' => 1,
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertTrue($validator->fails());
        $this->assertArrayHasKey('memory_mb', $validator->errors()->toArray());
    }

    /**
     * Test disk_gb validation
     */
    public function test_disk_gb_validation(): void
    {
        $data = [
            'vmid' => 100,
            'name' => 'test-container',
            'cores' => 2,
            'memory_mb' => 2048,
            'disk_gb' => 5, // Too low
            'template_id' => 1,
            'proxmox_server_id' => 1,
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertTrue($validator->fails());
        $this->assertArrayHasKey('disk_gb', $validator->errors()->toArray());
    }

    /**
     * Test template_id exists
     */
    public function test_template_id_exists(): void
    {
        $data = [
            'vmid' => 100,
            'name' => 'test-container',
            'cores' => 2,
            'memory_mb' => 2048,
            'disk_gb' => 50,
            'template_id' => 999, // Non-existent
            'proxmox_server_id' => 1,
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertTrue($validator->fails());
        $this->assertArrayHasKey('template_id', $validator->errors()->toArray());
    }

    /**
     * Test proxmox_server_id exists
     */
    public function test_proxmox_server_id_exists(): void
    {
        $data = [
            'vmid' => 100,
            'name' => 'test-container',
            'cores' => 2,
            'memory_mb' => 2048,
            'disk_gb' => 50,
            'template_id' => 1,
            'proxmox_server_id' => 999, // Non-existent
        ];

        $validator = Validator::make($data, (new StoreContainerRequest)->rules());

        $this->assertTrue($validator->fails());
        $this->assertArrayHasKey('proxmox_server_id', $validator->errors()->toArray());
    }

    /**
     * Test input sanitization
     */
    public function test_input_sanitization(): void
    {
        $request = new StoreContainerRequest;
        $request->merge([
            'vmid' => 100,
            'name' => '  test-container  ', // with spaces
            'cores' => 2,
            'memory_mb' => 2048,
            'disk_gb' => 50,
            'description' => '', // empty string
            'template_id' => 1,
            'proxmox_server_id' => 1,
        ]);

        $request->prepareForValidation();

        $this->assertEquals('test-container', $request->input('name'));
        $this->assertNull($request->input('description'));
    }

    /**
     * Test pagination rules helper
     */
    public function test_pagination_rules(): void
    {
        $request = new StoreContainerRequest;
        $paginationRules = $request->getPaginationRules();

        $this->assertArrayHasKey('page', $paginationRules);
        $this->assertArrayHasKey('per_page', $paginationRules);
        $this->assertArrayHasKey('sort_by', $paginationRules);
        $this->assertArrayHasKey('sort_order', $paginationRules);
    }

    /**
     * Test validation messages
     */
    public function test_validation_messages(): void
    {
        $messages = (new StoreContainerRequest)->messages();

        $this->assertIsArray($messages);
        $this->assertArrayHasKey('vmid.required', $messages);
        $this->assertArrayHasKey('name.required', $messages);
    }
}
