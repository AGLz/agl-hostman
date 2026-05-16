<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use Illuminate\Support\Facades\Validator;
use Tests\TestCase;

class SecureValidatorTest extends TestCase
{
    public function test_validated_preserves_sql_like_strings(): void
    {
        $validator = Validator::make(
            ['note' => 'UNION SELECT * FROM users'],
            ['note' => 'required|string']
        );

        $this->assertTrue($validator->passes());
        $this->assertSame('UNION SELECT * FROM users', $validator->validated()['note']);
    }
}
