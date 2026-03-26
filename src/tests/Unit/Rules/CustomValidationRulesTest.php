<?php

declare(strict_types=1);

namespace Tests\Unit\Rules;

use App\Rules\CustomValidationRules;
use Tests\TestCase;

/**
 * Custom Validation Rules Test
 *
 * Tests for custom validation rules.
 */
class CustomValidationRulesTest extends TestCase
{
    /**
     * Test ValidVmid rule
     */
    public function test_valid_vmid_rule(): void
    {
        $rule = new CustomValidationRules\ValidVmid;

        // Valid VMIDs
        $this->assertTrue($rule->passes('vmid', 100));
        $this->assertTrue($rule->passes('vmid', 999999999));
        $this->assertTrue($rule->passes('vmid', '100'));
        $this->assertTrue($rule->passes('vmid', '500'));

        // Invalid VMIDs
        $this->assertFalse($rule->passes('vmid', 99));
        $this->assertFalse($rule->passes('vmid', 1000000000));
        $this->assertFalse($rule->passes('vmid', 'abc'));
        $this->assertFalse($rule->passes('vmid', '99'));
        $this->assertFalse($rule->passes('vmid', '1000000000'));
        $this->assertFalse($rule->passes('vmid', null));
        $this->assertFalse($rule->passes('vmid', ''));

        // Check message
        $this->assertStringContainsString('valid VMID', $rule->message());
    }

    /**
     * Test ValidHostname rule
     */
    public function test_valid_hostname_rule(): void
    {
        $rule = new CustomValidationRules\ValidHostname;

        // Valid hostnames
        $this->assertTrue($rule->passes('hostname', 'localhost'));
        $this->assertTrue($rule->passes('hostname', 'example.com'));
        $this->assertTrue($rule->passes('hostname', 'sub.example.com'));
        $this->assertTrue($rule->passes('hostname', 'my-server'));
        $this->assertTrue($rule->passes('hostname', 'server01'));
        $this->assertTrue($rule->passes('hostname', 'test-server.example.com'));

        // Invalid hostnames
        $this->assertFalse($rule->passes('hostname', '-example.com'));
        $this->assertFalse($rule->passes('hostname', 'example-.com'));
        $this->assertFalse($rule->passes('hostname', 'example..com'));
        $this->assertFalse($rule->passes('hostname', '.example.com'));
        $this->assertFalse($rule->passes('hostname', 'example.com.'));

        // Long label (max 63 characters)
        $longLabel = str_repeat('a', 63);
        $this->assertTrue($rule->passes('hostname', $longLabel.'.com'));

        $tooLongLabel = str_repeat('a', 64);
        $this->assertFalse($rule->passes('hostname', $tooLongLabel.'.com'));

        // Check message
        $this->assertStringContainsString('valid hostname', $rule->message());
    }

    /**
     * Test ValidIPAddress rule
     */
    public function test_valid_ip_address_rule(): void
    {
        // Without CIDR
        $rule = new CustomValidationRules\ValidIPAddress(allowCidr: false);

        // Valid IPs
        $this->assertTrue($rule->passes('ip', '192.168.1.1'));
        $this->assertTrue($rule->passes('ip', '10.0.0.1'));
        $this->assertTrue($rule->passes('ip', '172.16.0.1'));
        $this->assertTrue($rule->passes('ip', '8.8.8.8'));
        $this->assertTrue($rule->passes('ip', '2001:4860:4860::8888'));

        // Invalid IPs
        $this->assertFalse($rule->passes('ip', '192.168.1.1/24')); // CIDR not allowed
        $this->assertFalse($rule->passes('ip', '256.1.1.1'));
        $this->assertFalse($rule->passes('ip', '192.168.1'));
        $this->assertFalse($rule->passes('ip', 'invalid'));

        // With CIDR
        $ruleWithCidr = new CustomValidationRules\ValidIPAddress(allowCidr: true);
        $this->assertTrue($ruleWithCidr->passes('ip', '192.168.1.0/24'));
        $this->assertTrue($ruleWithCidr->passes('ip', '10.0.0.0/8'));

        // With allowed ranges
        $ruleWithRanges = new CustomValidationRules\ValidIPAddress(
            allowCidr: false,
            allowedRanges: ['192.168.1.0/24', '10.0.0.0/8']
        );
        $this->assertTrue($ruleWithRanges->passes('ip', '192.168.1.100'));
        $this->assertTrue($ruleWithRanges->passes('ip', '10.0.0.1'));
        $this->assertFalse($ruleWithRanges->passes('ip', '8.8.8.8')); // Not in allowed range
        $this->assertFalse($ruleWithRanges->passes('ip', '192.168.2.1')); // Not in allowed range

        // Check message
        $this->assertStringContainsString('valid IP address', $rule->message());
    }

    /**
     * Test StrongPassword rule
     */
    public function test_strong_password_rule(): void
    {
        $rule = new CustomValidationRules\StrongPassword;

        // Strong passwords
        $this->assertTrue($rule->passes('password', 'MyStr0ng!Pass'));
        $this->assertTrue($rule->passes('password', 'Secure#12345'));
        $this->assertTrue($rule->passes('password', 'C0mplex@Password'));
        $this->assertTrue($rule->passes('password', 'Very$tr0ngPass2024'));

        // Weak passwords
        $this->assertFalse($rule->passes('password', 'short')); // Too short
        $this->assertFalse($rule->passes('password', 'alllowercase123')); // No uppercase
        $this->assertFalse($rule->passes('password', 'ALLUPPERCASE123')); // No lowercase
        $this->assertFalse($rule->passes('password', 'NoNumbers!')); // No numbers
        $this->assertFalse($rule->passes('password', 'NoSpecial123')); // No special char
        $this->assertFalse($rule->passes('password', 'Short1!')); // Too short

        // Custom requirements
        $customRule = new CustomValidationRules\StrongPassword(
            minLength: 16,
            requireUppercase: true,
            requireLowercase: true,
            requireNumber: true,
            requireSpecialChar: true
        );

        $this->assertTrue($customRule->passes('password', 'MyVeryStr0ng!Pass123'));
        $this->assertFalse($customRule->passes('password', 'Short1!')); // Too short

        // Check message
        $this->assertStringContainsString('strong password', $rule->message());
    }

    /**
     * Test SafeUrl rule
     */
    public function test_safe_url_rule(): void
    {
        $rule = new CustomValidationRules\SafeUrl;

        // Safe URLs
        $this->assertTrue($rule->passes('url', 'https://example.com'));
        $this->assertTrue($rule->passes('url', 'https://api.example.com/endpoint'));
        $this->assertTrue($rule->passes('url', 'http://public-api.com'));

        // Unsafe URLs (private IPs)
        $this->assertFalse($rule->passes('url', 'http://192.168.1.1'));
        $this->assertFalse($rule->passes('url', 'http://10.0.0.1'));
        $this->assertFalse($rule->passes('url', 'http://172.16.0.1'));
        $this->assertFalse($rule->passes('url', 'http://localhost'));
        $this->assertFalse($rule->passes('url', 'http://127.0.0.1'));

        // Invalid URLs
        $this->assertFalse($rule->passes('url', 'not-a-url'));
        $this->assertFalse($rule->passes('url', 'ftp://example.com')); // file:// protocol blocked

        // With allowed hosts
        $ruleWithHosts = new CustomValidationRules\SafeUrl(
            allowedHosts: ['api.example.com', 'cdn.example.com']
        );

        $this->assertTrue($ruleWithHosts->passes('url', 'https://api.example.com'));
        $this->assertTrue($ruleWithHosts->passes('url', 'https://cdn.example.com'));
        $this->assertFalse($ruleWithHosts->passes('url', 'https://other.com'));

        // Check message
        $this->assertStringContainsString('safe URL', $rule->message());
    }

    /**
     * Test ValidJson rule
     */
    public function test_valid_json_rule(): void
    {
        $rule = new CustomValidationRules\ValidJson;

        // Valid JSON
        $this->assertTrue($rule->passes('data', '{"key":"value"}'));
        $this->assertTrue($rule->passes('data', '{"array":[1,2,3]}'));
        $this->assertTrue($rule->passes('data', '{"nested":{"key":"value"}}'));
        $this->assertTrue($rule->passes('data', '[]'));
        $this->assertTrue($rule->passes('data', '{}'));
        $this->assertTrue($rule->passes('data', 'null'));
        $this->assertTrue($rule->passes('data', 'true'));
        $this->assertTrue($rule->passes('data', 'false'));
        $this->assertTrue($rule->passes('data', '123'));
        $this->assertTrue($rule->passes('data', '"string"'));

        // Invalid JSON
        $this->assertFalse($rule->passes('data', '{not json}'));
        $this->assertFalse($rule->passes('data', '{"key": value}')); // Missing quotes
        $this->assertFalse($rule->passes('data', '{"key": "value"')); // Missing closing brace
        $this->assertFalse($rule->passes('data', 'not json at all'));
        $this->assertFalse($rule->passes('data', ''));

        // Check message
        $this->assertStringContainsString('valid JSON', $rule->message());
    }

    /**
     * Test validation rule with attribute name
     */
    public function test_validation_rule_with_attribute(): void
    {
        $rule = new CustomValidationRules\ValidVmid;

        $rule->setAttribute('vmid');

        $this->assertEquals('vmid', $rule->getAttribute());

        $rule->passes('vmid', 99);

        $message = $rule->message();
        $this->assertStringContainsString('vmid', $message);
    }
}
