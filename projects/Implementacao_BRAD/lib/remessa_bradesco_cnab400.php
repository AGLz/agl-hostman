<?php
/**
 * Gera arquivo remessa CNAB400 Bradesco (1 header + N detalhes + trailer).
 * Baseado no layout oficial e em eduardokum/laravel-boleto (referência).
 */
require_once dirname(__FILE__) . '/cnab_util.php';

function brad_remessa_gerar($config, $titulos, $sequencialMx)
{
    $lines = array();
    $seq = 1;

    $line = brad_cnab_line_fill(400);
    brad_cnab_set($line, 1, 1, '0');
    brad_cnab_set($line, 2, 2, '1');
    brad_cnab_set($line, 3, 9, 'REMESSA');
    brad_cnab_set($line, 10, 11, '01');
    brad_cnab_set($line, 12, 26, brad_cnab_pad_alpha('COBRANCA', 15));
    brad_cnab_set($line, 27, 46, brad_cnab_pad_num($config['convenio'], 20));
    brad_cnab_set($line, 47, 76, brad_cnab_pad_alpha($config['razao_social'], 30));
    brad_cnab_set($line, 77, 79, '237');
    brad_cnab_set($line, 80, 94, brad_cnab_pad_alpha('BRADESCO', 15));
    brad_cnab_set($line, 95, 100, date('dmy'));
    brad_cnab_set($line, 109, 110, 'MX');
    brad_cnab_set($line, 111, 117, brad_cnab_pad_num($sequencialMx, 7));
    brad_cnab_set($line, 395, 400, brad_cnab_pad_num($seq, 6));
    $lines[] = $line;
    $seq++;

    foreach ($titulos as $t) {
        $nosso12 = brad_dv_nosso_numero_bradesco($config['carteira'], $t['nosso_numero']);
        if (strlen($nosso12) == 12 && !ctype_digit($nosso12)) {
            $nosso12 = substr($nosso12, 0, 11) . '0';
        }
        $nosso12 = brad_cnab_pad_num($nosso12, 12);

        $benefId = brad_cnab_pad_num($config['carteira'], 4)
            . brad_cnab_pad_num($config['agencia'], 5)
            . brad_cnab_pad_num($config['conta'], 7)
            . brad_cnab_pad_num($config['conta_dv'], 1);

        $docPag = brad_cnab_only_numbers($t['pagador_documento']);
        $tipoDoc = (strlen($docPag) == 14) ? '02' : '01';

        $line = brad_cnab_line_fill(400);
        brad_cnab_set($line, 1, 1, '1');
        brad_cnab_set($line, 21, 37, $benefId);
        brad_cnab_set($line, 38, 62, brad_cnab_pad_alpha(isset($t['numero_controle']) ? $t['numero_controle'] : ('BOL' . $t['nosso_numero']), 25));
        brad_cnab_set($line, 63, 65, '237');
        brad_cnab_set($line, 66, 66, '0');
        brad_cnab_set($line, 71, 82, $nosso12);
        brad_cnab_set($line, 93, 93, '2');
        brad_cnab_set($line, 106, 106, '2');
        brad_cnab_set($line, 109, 110, '01');
        brad_cnab_set($line, 111, 120, brad_cnab_pad_alpha($t['numero_documento'], 10));
        brad_cnab_set($line, 121, 126, date('dmy', strtotime($t['data_vencimento'])));
        brad_cnab_set($line, 127, 139, brad_cnab_pad_num($t['valor'], 13, 2));
        brad_cnab_set($line, 148, 149, '01');
        brad_cnab_set($line, 150, 150, 'N');
        brad_cnab_set($line, 151, 156, date('dmy', strtotime($t['data_documento'])));
        brad_cnab_set($line, 219, 220, $tipoDoc);
        brad_cnab_set($line, 221, 234, brad_cnab_pad_num($docPag, 14));
        brad_cnab_set($line, 235, 274, brad_cnab_pad_alpha($t['pagador_nome'], 40));
        brad_cnab_set($line, 275, 314, brad_cnab_pad_alpha($t['pagador_endereco'], 40));
        brad_cnab_set($line, 315, 326, brad_cnab_pad_alpha($t['pagador_bairro'], 12));
        brad_cnab_set($line, 327, 334, brad_cnab_pad_num(brad_cnab_only_numbers($t['pagador_cep']), 8));
        brad_cnab_set($line, 395, 400, brad_cnab_pad_num($seq, 6));
        $lines[] = $line;
        $seq++;
    }

    $line = brad_cnab_line_fill(400);
    brad_cnab_set($line, 1, 1, '9');
    brad_cnab_set($line, 395, 400, brad_cnab_pad_num($seq, 6));
    $lines[] = $line;

    return implode("\r\n", $lines) . "\r\n";
}
