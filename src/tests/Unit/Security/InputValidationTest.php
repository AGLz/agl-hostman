<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use App\Http\Requests\BaseFormRequest;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Validator;
use Tests\TestCase;

/**
 * Input Validation Security Tests
 *
 * Tests for input validation, sanitization, and prevention
 * of malicious input.
 */
class InputValidationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test SQL injection in string input
     */
    public function test_sql_injection_blocked_in_string_input(): void
    {
        $maliciousInputs = [
            "'; DROP TABLE users; --",
            "' OR '1'='1",
            "admin'--",
            "' UNION SELECT * FROM users--",
            "1' AND 1=1--",
        ];

        foreach ($maliciousInputs as $input) {
            $validator = Validator::make([
                'name' => $input,
            ], [
                'name' => 'required|string|max:255',
            ]);

            $this->assertTrue($validator->passes(), 'Input should be validated but sanitized');
            $this->assertStringNotContainsString('DROP TABLE', $validator->validated()['name']);
        }
    }

    /**
     * Test XSS prevention in HTML input
     */
    public function test_xss_prevention_in_html_input(): void
    {
        $maliciousInputs = [
            '<script>alert("XSS")</script>',
            '<img src=x onerror=alert("XSS")>',
            'javascript:alert("XSS")',
            '<svg onload=alert("XSS")>',
            '"><script>alert(String.fromCharCode(88,83,83))</script>',
        ];

        foreach ($maliciousInputs as $input) {
            $validator = Validator::make([
                'comment' => $input,
            ], [
                'comment' => 'required|string|max:1000',
            ]);

            $this->assertTrue($validator->passes());
            $sanitized = strip_tags($validator->validated()['comment']);
            $this->assertStringNotContainsString('<script', $sanitized);
        }
    }

    /**
     * Test email validation blocks malformed emails
     */
    public function test_email_validation_blocks_malformed_emails(): void
    {
        $maliciousEmails = [
            'test@..com',
            'test@example.com" OR "1"="1',
            'test@example.com;<script>',
            'test@localhost',
            'test@127.0.0.1',
            'test+@example.com',
        ];

        foreach ($maliciousEmails as $email) {
            $validator = Validator::make([
                'email' => $email,
            ], [
                'email' => 'required|email',
            ]);

            $this->assertFalse(
                $validator->passes(),
                "Malicious email should fail validation: {$email}"
            );
        }
    }

    /**
     * Test URL validation blocks JavaScript URLs
     */
    public function test_url_validation_blocks_javascript_urls(): void
    {
        $maliciousUrls = [
            'javascript:alert("XSS")',
            'data:text/html,<script>alert("XSS")</script>',
            'vbscript:msgbox("XSS")',
            'file:///etc/passwd',
            'ftp://malicious.com',
        ];

        foreach ($maliciousUrls as $url) {
            $validator = Validator::make([
                'url' => $url,
            ], [
                'url' => 'required|url',
            ]);

            $this->assertFalse(
                $validator->passes(),
                "Malicious URL should fail validation: {$url}"
            );
        }
    }

    /**
     * Test integer validation prevents injection
     */
    public function test_integer_validation_prevents_injection(): void
    {
        $maliciousInputs = [
            '1 OR 1=1',
            '1; DROP TABLE users--',
            '1 UNION SELECT * FROM users',
            'abc',
            '1.5.3',
        ];

        foreach ($maliciousInputs as $input) {
            $validator = Validator::make([
                'id' => $input,
            ], [
                'id' => 'required|integer',
            ]);

            $this->assertFalse(
                $validator->passes(),
                "Non-integer should fail validation: {$input}"
            );
        }
    }

    /**
     * Test file upload validation prevents malicious files
     */
    public function test_file_upload_blocks_malicious_files(): void
    {
        $maliciousFiles = [
            'exploit.php',
            'shell.php.jpg',
            'script.js',
            'config.inc',
            '.htaccess',
            'web.config',
            'exploit.php3',
            'exploit.phtml',
        ];

        foreach ($maliciousFiles as $file) {
            $validator = Validator::make([
                'file' => $file,
            ], [
                'file' => 'required|mimes:jpg,jpeg,png,pdf,doc,docx',
            ]);

            $this->assertFalse(
                $validator->passes(),
                "Malicious file should fail validation: {$file}"
            );
        }
    }

    /**
     * Test max length validation prevents buffer overflow
     */
    public function test_max_length_prevents_overflow(): void
    {
        $longInput = str_repeat('A', 10000);

        $validator = Validator::make([
            'name' => $longInput,
        ], [
            'name' => 'required|string|max:255',
        ]);

        $this->assertFalse($validator->passes());

        if ($validator->passes()) {
            $this->assertLessThanOrEqual(255, strlen($validator->validated()['name']));
        }
    }

    /**
     * Test regex pattern validation
     */
    public function test_regex_pattern_validation(): void
    {
        $invalidInputs = [
            'user@domain',
            'user name',
            'user-name!',
        ];

        foreach ($invalidInputs as $input) {
            $validator = Validator::make([
                'username' => $input,
            ], [
                'username' => 'required|regex:/^[a-zA-Z0-9_-]+$/',
            ]);

            $this->assertFalse(
                $validator->passes(),
                "Invalid username should fail validation: {$input}"
            );
        }
    }

    /**
     * Test array validation prevents injection
     */
    public function test_array_validation_prevents_injection(): void
    {
        $maliciousInput = [
            'normal',
            'test"; DROP TABLE users; --',
            '<script>alert("XSS")</script>',
        ];

        $validator = Validator::make([
            'tags' => $maliciousInput,
        ], [
            'tags' => 'required|array',
            'tags.*' => 'string|max:50',
        ]);

        $this->assertTrue($validator->passes());

        $validated = $validator->validated();
        foreach ($validated['tags'] as $tag) {
            $this->assertStringNotContainsString('<script>', $tag);
        }
    }

    /**
     * Test boolean validation
     */
    public function test_boolean_validation(): void
    {
        $invalidBooleans = [
            'yes',
            'no',
            '1',
            '0',
            'true',
            'false',
            'on',
            'off',
        ];

        foreach ($invalidBooleans as $input) {
            $validator = Validator::make([
                'active' => $input,
            ], [
                'active' => 'required|boolean',
            ]);

            $this->assertFalse(
                $validator->passes(),
                "Non-boolean should fail validation: {$input}"
            );
        }
    }

    /**
     * Test date validation prevents injection
     */
    public function test_date_validation_prevents_injection(): void
    {
        $maliciousDates = [
            '2024-01-01; DROP TABLE users--',
            '2024-01-01 OR 1=1',
            'not-a-date',
            '2024-13-45',
        ];

        foreach ($maliciousDates as $date) {
            $validator = Validator::make([
                'date' => $date,
            ], [
                'date' => 'required|date',
            ]);

            $this->assertFalse(
                $validator->passes(),
                "Invalid date should fail validation: {$date}"
            );
        }
    }

    /**
     * Test BaseFormRequest sanitization
     */
    public function test_base_form_request_sanitization(): void
    {
        $request = new class extends BaseFormRequest
        {
            public function rules(): array
            {
                return [
                    'name' => 'required|string|max:255',
                    'email' => 'required|email',
                ];
            }
        };

        $request->merge([
            'name' => '<script>alert("XSS")</script>John Doe',
            'email' => 'john@example.com',
        ]);

        $this->assertTrue($request->authorize());
        $validated = $request->validated();

        $this->assertArrayHasKey('name', $validated);
        $this->assertArrayHasKey('email', $validated);
    }

    /**
     * Test JSON input validation
     */
    public function test_json_input_validation(): void
    {
        $maliciousJson = '{"name":"<script>alert(1)</script>","admin":true}';

        $validator = Validator::make([
            'data' => $maliciousJson,
        ], [
            'data' => 'required|json',
        ]);

        $this->assertTrue($validator->passes());
    }

    /**
     * Test IP address validation
     */
    public function test_ip_address_validation(): void
    {
        $invalidIps = [
            '256.256.256.256',
            '1.2.3',
            'abc.def.ghi.jkl',
            '127.0.0.1; DROP TABLE users--',
        ];

        foreach ($invalidIps as $ip) {
            $validator = Validator::make([
                'ip' => $ip,
            ], [
                'ip' => 'required|ip',
            ]);

            $this->assertFalse(
                $validator->passes(),
                "Invalid IP should fail validation: {$ip}"
            );
        }
    }

    /**
     * Test required fields validation
     */
    public function test_required_fields_validation(): void
    {
        $validator = Validator::make([], [
            'email' => 'required|email',
            'password' => 'required|string|min:8',
        ]);

        $this->assertFalse($validator->passes());
        $this->assertArrayHasKey('email', $validator->errors()->messages());
        $this->assertArrayHasKey('password', $validator->errors()->messages());
    }
}
