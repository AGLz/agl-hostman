<?php
/**
 * Utilitários CNAB posicional — PHP 5.6, sem dependências externas.
 */

function brad_cnab_only_numbers($s)
{
    return preg_replace('/\D/', '', (string) $s);
}

function brad_cnab_pad_num($value, $length, $decimals = 0)
{
    if ($decimals > 0) {
        $value = number_format((float) $value, $decimals, '', '');
    }
    $value = brad_cnab_only_numbers($value);
    return str_pad($value, $length, '0', STR_PAD_LEFT);
}

function brad_cnab_pad_alpha($value, $length)
{
    $value = strtoupper(substr((string) $value, 0, $length));
    return str_pad($value, $length, ' ', STR_PAD_RIGHT);
}

function brad_cnab_line_fill($length)
{
    return str_pad('', $length, ' ', STR_PAD_RIGHT);
}

function brad_cnab_set(&$line, $start, $end, $value)
{
    $len = $end - $start + 1;
    $line = substr($line, 0, $start - 1) . substr($value, 0, $len) . substr($line, $end);
}

function brad_dv_nosso_numero_bradesco($carteira, $numero)
{
    $nnum = str_pad((string) $carteira, 2, '0', STR_PAD_LEFT)
        . str_pad((string) $numero, 11, '0', STR_PAD_LEFT);
    $resto2 = brad_modulo_11($nnum, 7, 1);
    $digito = 11 - $resto2;
    if ($digito == 10) {
        return $nnum . 'P';
    }
    if ($digito == 11) {
        return $nnum . '0';
    }
    return $nnum . (string) $digito;
}

function brad_modulo_11($num, $base, $r)
{
    $soma = 0;
    $fator = 2;
    for ($i = strlen($num) - 1; $i >= 0; $i--) {
        $soma += (int) $num[$i] * $fator;
        $fator = ($fator == $base) ? 1 : $fator + 1;
    }
    if ($r == 0) {
        $resto = $soma % 11;
        return $resto;
    }
    return $soma % 11;
}
