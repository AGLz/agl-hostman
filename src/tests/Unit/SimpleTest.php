<?php

test('basic php works', function () {
    expect(true)->toBeTrue();
    expect(1 + 1)->toBe(2);
});

test('can create array', function () {
    $array = ['a' => 1, 'b' => 2];
    expect($array)->toHaveKey('a');
    expect($array['a'])->toBe(1);
});
