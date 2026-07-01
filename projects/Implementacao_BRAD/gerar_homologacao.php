<?php
/**
 * Gerador offline homologação Bradesco (PHP 5.6).
 * Uso: php gerar_homologacao.php [--seq=N] [--nn=N]
 */
error_reporting(E_ALL);
ini_set('display_errors', 1);

$baseDir = dirname(__FILE__);
$config = require $baseDir . '/config.homolog.php';
require_once $baseDir . '/lib/remessa_bradesco_cnab400.php';

$seq = (int) $config['sequencial_remessa_inicial'];
$nn = (int) $config['nosso_numero_inicial'];

foreach (array_slice($argv, 1) as $arg) {
    if (preg_match('/^--seq=(\d+)$/', $arg, $m)) {
        $seq = (int) $m[1];
    }
    if (preg_match('/^--nn=(\d+)$/', $arg, $m)) {
        $nn = (int) $m[1];
    }
}

$outDir = $baseDir . '/output';
if (!is_dir($outDir)) {
    mkdir($outDir, 0755, true);
}

$vencTs = strtotime('+' . (int) $config['dias_vencimento'] . ' days');
$dataVenc = date('d/m/Y', $vencTs);
$dataDoc = date('d/m/Y');
$valor = number_format((float) $config['valor_teste'], 2, ',', '.');

$dadosboleto = array();
$dadosboleto['nosso_numero'] = (string) $nn;
$dadosboleto['numero_documento'] = $dadosboleto['nosso_numero'];
$dadosboleto['data_vencimento'] = $dataVenc;
$dadosboleto['data_documento'] = $dataDoc;
$dadosboleto['data_processamento'] = $dataDoc;
$dadosboleto['valor_boleto'] = $valor;
$dadosboleto['sacado'] = $config['pagador_nome'];
$dadosboleto['endereco1'] = $config['pagador_endereco'];
$dadosboleto['endereco2'] = $config['pagador_cidade'] . ' - ' . $config['pagador_uf'] . ' - CEP: ' . $config['pagador_cep'];
$dadosboleto['demonstrativo1'] = 'Cobranca teste homologacao Bradesco';
$dadosboleto['demonstrativo2'] = 'Nao utilizar para pagamento real';
$dadosboleto['demonstrativo3'] = 'FALG Administracao e Vendas Ltda';
$dadosboleto['instrucoes1'] = '- Boleto de homologacao';
$dadosboleto['instrucoes2'] = '- Nao receber apos o vencimento';
$dadosboleto['instrucoes3'] = '- Duvidas: adm@falg.com.br';
$dadosboleto['instrucoes4'] = 'Emitido para homologacao CNAB400';
$dadosboleto['quantidade'] = '001';
$dadosboleto['valor_unitario'] = $valor;
$dadosboleto['aceite'] = '';
$dadosboleto['especie'] = 'R$';
$dadosboleto['especie_doc'] = 'DM';
$dadosboleto['agencia'] = $config['agencia'];
$dadosboleto['agencia_dv'] = $config['agencia_dv'];
$dadosboleto['conta'] = $config['conta'];
$dadosboleto['conta_dv'] = $config['conta_dv'];
$dadosboleto['conta_cedente'] = $config['conta'];
$dadosboleto['conta_cedente_dv'] = $config['conta_dv'];
$dadosboleto['carteira'] = $config['carteira'];
$dadosboleto['identificacao'] = 'FALG Administracao e Vendas Ltda';
$dadosboleto['cpf_cnpj'] = $config['cnpj'];
$dadosboleto['endereco'] = $config['endereco_cedente'];
$dadosboleto['cidade_uf'] = $config['cidade_cedente'] . ' / ' . $config['uf_cedente'];
$dadosboleto['cedente'] = $config['cedente_nome_curto'];

$boletoDir = dirname($baseDir) . '/public_html/boleto_enviado_bradesco';
$cwd = getcwd();
chdir($boletoDir);
ob_start();
include $boletoDir . '/include/funcoes_bradesco.php';
include $boletoDir . '/include/layout_bradesco.php';
$html = ob_get_clean();
chdir($cwd);

$stamp = date('Ymd-His');
$baseName = 'FALG' . $stamp;
$htmlFile = $outDir . '/boleto-homolog-' . $stamp . '.html';
$pdfFile = $outDir . '/boleto-homolog-' . $stamp . '.pdf';
$remessaFile = $outDir . '/' . $baseName . '.rem';

file_put_contents($htmlFile, $html);

$mpdfPath = dirname($baseDir) . '/public_html/include/mpdf/mpdf.php';
if (is_file($mpdfPath)) {
    require_once $mpdfPath;
    $mpdf = new mPDF('win-1252', 'A4', 0, '', 5, 5, 5, 5);
    $mpdf->WriteHTML($html);
    $mpdf->Output($pdfFile, 'F');
} else {
    fwrite(STDERR, "AVISO: mPDF nao encontrado; apenas HTML gerado.\n");
    $pdfFile = '(nao gerado - abrir HTML e imprimir em PDF)';
}

$titulo = array(
    'nosso_numero' => $nn,
    'numero_documento' => 'HOM' . str_pad((string) $nn, 7, '0', STR_PAD_LEFT),
    'numero_controle' => 'HOM' . $nn,
    'data_vencimento' => date('Y-m-d', $vencTs),
    'data_documento' => date('Y-m-d'),
    'valor' => (float) $config['valor_teste'],
    'pagador_nome' => $config['pagador_nome'],
    'pagador_documento' => $config['pagador_documento'],
    'pagador_endereco' => $config['pagador_endereco'],
    'pagador_bairro' => $config['pagador_bairro'],
    'pagador_cep' => $config['pagador_cep'],
);

$remessaBody = brad_remessa_gerar($config, array($titulo), $seq);
file_put_contents($remessaFile, $remessaBody);

$lines = preg_split('/\r\n|\n/', trim($remessaBody));
$lineLen = strlen(rtrim($lines[0], "\r\n"));

echo "=== Homologacao Bradesco gerada ===\n";
echo "Remessa:     $remessaFile\n";
echo "PDF:         $pdfFile\n";
echo "HTML:        $htmlFile\n";
echo "Sequencial:  MX " . str_pad((string) $seq, 7, '0', STR_PAD_LEFT) . "\n";
echo "Nosso num.:  $nn\n";
echo "Linhas rem.: " . count($lines) . " x {$lineLen} chars\n";
echo "Vencimento:  $dataVenc\n";
echo "Valor:       R$ " . number_format((float) $config['valor_teste'], 2, ',', '.') . "\n";
echo "\nEnvie ao banco: 1 arquivo .rem + 1 PDF (e-mail homologacao).\n";
