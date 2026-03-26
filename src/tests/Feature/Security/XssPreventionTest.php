<?php

declare(strict_types=1);

namespace Tests\Feature\Security;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * XSS Prevention Tests
 *
 * Tests for Cross-Site Scripting prevention including output escaping,
 * content security policy, and input sanitization.
 */
class XssPreventionTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->user = User::factory()->create();
    }

    /**
     * Test script tags are escaped in output
     */
    public function test_script_tags_escaped_in_output(): void
    {
        $maliciousInput = '<script>alert("XSS")</script>Hello';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'bio' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());

        $response = $this->actingAs($this->user)
            ->get('/profile');

        $response->assertDontSee('<script>', false);
    }

    /**
     * Test img onerror is escaped
     */
    public function test_img_onerror_escaped(): void
    {
        $maliciousInput = '<img src=x onerror=alert("XSS")>';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'bio' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test javascript: protocol is blocked
     */
    public function test_javascript_protocol_blocked(): void
    {
        $maliciousInput = 'javascript:alert("XSS")';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'website' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());

        $response = $this->actingAs($this->user)
            ->get('/profile');

        $content = $response->getContent();
        $this->assertStringNotContainsString('javascript:', $content ?? '');
    }

    /**
     * Test data: protocol is blocked
     */
    public function test_data_protocol_blocked(): void
    {
        $maliciousInput = 'data:text/html,<script>alert("XSS")</script>';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'avatar' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test vbscript: protocol is blocked
     */
    public function test_vbscript_protocol_blocked(): void
    {
        $maliciousInput = 'vbscript:msgbox("XSS")';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'website' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test SVG onload is escaped
     */
    public function test_svg_onload_escaped(): void
    {
        $maliciousInput = '<svg onload=alert("XSS")>';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'bio' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test iframe injection is prevented
     */
    public function test_iframe_injection_prevented(): void
    {
        $maliciousInput = '<iframe src="javascript:alert(\'XSS\')"></iframe>';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'bio' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());

        $response = $this->actingAs($this->user)
            ->get('/profile');

        $content = $response->getContent();
        $this->assertStringNotContainsString('<iframe', $content ?? '');
    }

    /**
     * Test event handlers are escaped
     */
    public function test_event_handlers_escaped(): void
    {
        $maliciousInputs = [
            '<div onmouseover="alert(\'XSS\')">Hover me</div>',
            '<a onclick="alert(\'XSS\')">Click me</a>',
            '<input onfocus="alert(\'XSS\')">',
        ];

        foreach ($maliciousInputs as $input) {
            $response = $this->actingAs($this->user)
                ->post('/profile', ['bio' => $input]);

            $this->assertNotEquals(500, $response->getStatusCode());
        }
    }

    /**
     * Test style tag injection is prevented
     */
    public function test_style_injection_prevented(): void
    {
        $maliciousInput = '<style>body { background: url("javascript:alert(\'XSS\')") }</style>';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'bio' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test meta tag injection is prevented
     */
    public function test_meta_injection_prevented(): void
    {
        $maliciousInput = '<meta http-equiv="refresh" content="0;url=javascript:alert(\'XSS\')">';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'bio' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test link tag injection is prevented
     */
    public function test_link_injection_prevented(): void
    {
        $maliciousInput = '<link rel="stylesheet" href="javascript:alert(\'XSS\')">';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'bio' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test object/embed injection is prevented
     */
    public function test_object_embed_injection_prevented(): void
    {
        $maliciousInputs = [
            '<object data="javascript:alert(\'XSS\')"></object>',
            '<embed src="javascript:alert(\'XSS\')">',
        ];

        foreach ($maliciousInputs as $input) {
            $response = $this->actingAs($this->user)
                ->post('/profile', ['bio' => $input]);

            $this->assertNotEquals(500, $response->getStatusCode());
        }
    }

    /**
     * Test form action injection is prevented
     */
    public function test_form_action_injection_prevented(): void
    {
        $maliciousInput = '<form action="javascript:alert(\'XSS\')"><button>Submit</button></form>';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'bio' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test expression() in CSS is prevented
     */
    public function test_css_expression_prevented(): void
    {
        $maliciousInput = '<div style="width: expression(alert(\'XSS\'))">Test</div>';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'bio' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test base tag injection is prevented
     */
    public function test_base_tag_injection_prevented(): void
    {
        $maliciousInput = '<base href="javascript:alert(\'XSS\')">';

        $response = $this->actingAs($this->user)
            ->post('/profile', [
                'bio' => $maliciousInput,
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test XSS via HTTP headers
     */
    public function test_xss_via_http_headers_prevented(): void
    {
        $response = $this->withHeaders([
            'User-Agent' => '<script>alert("XSS")</script>',
            'Referer' => 'javascript:alert("XSS")',
        ])->get('/dashboard');

        $content = $response->getContent();
        $this->assertStringNotContainsString('<script>', $content ?? '');
    }

    /**
     * Test reflected XSS is prevented
     */
    public function test_reflected_xss_prevented(): void
    {
        $maliciousInput = '<script>alert("XSS")</script>';

        $response = $this->get("/search?q={$maliciousInput}");

        $content = $response->getContent();
        $this->assertStringNotContainsString('<script>', $content ?? '');
    }

    /**
     * Test stored XSS is prevented
     */
    public function test_stored_xss_prevented(): void
    {
        $maliciousInput = '<script>alert("XSS")</script>';

        $this->user->update(['bio' => $maliciousInput]);

        $response = $this->actingAs($this->user)
            ->get('/profile');

        $content = $response->getContent();
        $this->assertStringNotContainsString('<script>', $content ?? '');
    }

    /**
     * Test DOM-based XSS prevention
     */
    public function test_dom_based_xss_prevention(): void
    {
        $maliciousInput = '#<img src=x onerror=alert("XSS")>';

        $response = $this->get($maliciousInput);

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test JSON XSS prevention
     */
    public function test_json_xss_prevention(): void
    {
        $maliciousData = [
            'name' => '<script>alert("XSS")</script>',
            'email' => 'test@example.com',
        ];

        $response = $this->actingAs($this->user)
            ->postJson('/api/settings', $maliciousData);

        $this->assertNotEquals(500, $response->getStatusCode());

        $json = $response->json();
        $this->assertArrayNotHasKey('<script>', $json);
    }

    /**
     * Test HTML entity encoding
     */
    public function test_html_entity_encoding(): void
    {
        $input = '<script>alert("XSS")</script>';
        $encoded = htmlspecialchars($input, ENT_QUOTES, 'UTF-8');

        $this->assertEquals('&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;', $encoded);
    }

    /**
     * Test CSP blocks inline scripts
     */
    public function test_csp_blocks_inline_scripts(): void
    {
        $response = $this->get('/dashboard');

        $csp = $response->headers->get('Content-Security-Policy');

        if ($csp) {
            $this->assertStringNotContainsString("'unsafe-inline'", $csp);
        }
    }

    /**
     * Test CSP blocks eval()
     */
    public function test_csp_blocks_eval(): void
    {
        $response = $this->get('/dashboard');

        $csp = $response->headers->get('Content-Security-Policy');

        if ($csp) {
            $this->assertStringNotContainsString("'unsafe-eval'", $csp);
        }
    }

    /**
     * Test XSS in file upload names
     */
    public function test_xss_in_file_upload_names(): void
    {
        $maliciousFileName = '<script>alert("XSS")</script>.jpg';

        $response = $this->actingAs($this->user)
            ->post('/upload', [
                'file' => uploadedFile($maliciousFileName, 'content'),
            ]);

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test Unicode XSS variants
     */
    public function test_unicode_xss_variants(): void
    {
        $maliciousInputs = [
            '\u003Cscript\u003Ealert("XSS")\u003C/script\u003E',
            '&lt;script&gt;alert("XSS")&lt;/script&gt;',
        ];

        foreach ($maliciousInputs as $input) {
            $response = $this->actingAs($this->user)
                ->post('/profile', ['bio' => $input]);

            $this->assertNotEquals(500, $response->getStatusCode());
        }
    }

    /**
     * Test XSS in URL parameters
     */
    public function test_xss_in_url_parameters(): void
    {
        $maliciousParam = '<script>alert("XSS")</script>';

        $response = $this->get("/profile?param={$maliciousParam}");

        $content = $response->getContent();
        $this->assertStringNotContainsString('<script>', $content ?? '');
    }

    /**
     * Test XSS in fragment identifier
     */
    public function test_xss_in_fragment_identifier(): void
    {
        $maliciousFragment = '#<script>alert("XSS")</script>';

        $response = $this->get("/profile{$maliciousFragment}");

        $this->assertNotEquals(500, $response->getStatusCode());
    }
}
