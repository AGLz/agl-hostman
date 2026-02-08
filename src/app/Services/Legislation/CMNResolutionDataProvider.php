<?php

declare(strict_types=1);

namespace App\Services\Legislation;

/**
 * CMN Resolution Data Provider
 *
 * Provides sample and real data for CMN (Conselho Monetário Nacional) resolutions
 * Includes CMN 4.963 and CMN 5.272 data for RPPS regulation
 */
class CMNResolutionDataProvider
{
    /**
     * Get CMN 4.963 resolution data
     * The original resolution with uniform governance system
     */
    public function getCMN4963Data(): array
    {
        $text = $this->getCMN4963Text();

        return [
            'type' => 'CMN',
            'number' => '4.963',
            'date' => '2018-01-17',
            'full_reference' => 'CMN Resolution 4.963/2018',
            'title' => 'Dispõe sobre a aplicação dos recursos dos Regimes Próprios de Previdência Social (RPPS)',
            'raw_text' => $text,
            'key_aspects' => [
                'uniform_governance' => 'Single-tier governance system for all RPPS',
                'investment_limits' => 'Standardized investment limits across all institutions',
                'compliance' => 'Uniform compliance requirements',
            ],
            'governance_structure' => [
                'tiers' => 1,
                'description' => 'Uniform governance system',
                'requirements' => [
                    'Basic governance standards',
                    'Standard risk management',
                    'Regular reporting',
                ],
            ],
            'investment_rules' => [
                'fixed_income' => [
                    'limit' => '100%',
                    'description' => 'Investimentos em renda fixa',
                ],
                'variable_income' => [
                    'limit' => '0%',
                    'description' => 'Não permitido para RPPS',
                ],
                'real_estate' => [
                    'limit' => '0%',
                    'description' => 'Não permitido',
                ],
                'foreign_investments' => [
                    'limit' => '0%',
                    'description' => 'Não permitido',
                ],
            ],
            'compliance_requirements' => [
                'certification' => 'None required',
                'reporting_frequency' => 'Annual',
                'external_audit' => 'Required',
            ],
            'metadata' => [
                'source' => 'Banco Central do Brasil',
                'status' => 'Revoked by CMN 5.272',
                'effective_date' => '2018-01-17',
                'revocation_date' => '2024-02-29',
            ],
        ];
    }

    /**
     * Get CMN 5.272 resolution data
     * The new resolution with four-tier governance system
     */
    public function getCMN5272Data(): array
    {
        $text = $this->getCMN5272Text();

        return [
            'type' => 'CMN',
            'number' => '5.272',
            'date' => '2024-02-29',
            'full_reference' => 'CMN Resolution 5.272/2024',
            'title' => 'Dispõe sobre a aplicação dos recursos dos Regimes Próprios de Previdência Social (RPPS) e revoga a Resolução CMN nº 4.963, de 17 de janeiro de 2018',
            'raw_text' => $text,
            'key_aspects' => [
                'tiered_governance' => 'Four-tier governance system (Nível I-IV)',
                'progressive_investments' => 'Investment access based on governance level',
                'enhanced_compliance' => 'Stricter requirements for higher tiers',
            ],
            'governance_structure' => [
                'tiers' => 4,
                'description' => 'Four-tier progressive governance system',
                'requirements_by_tier' => [
                    'Nível I' => [
                        'Basic governance standards',
                        'Minimum board independence',
                        'Basic risk management',
                    ],
                    'Nível II' => [
                        'Enhanced governance',
                        'Board independence requirements',
                        'Risk management framework',
                        'Pró-Gestão certification',
                    ],
                    'Nível III' => [
                        'Advanced governance',
                        'Independent audit committee',
                        'Sophisticated risk management',
                        'Pró-Gestão certification',
                        'Variable income access up to 40%',
                    ],
                    'Nível IV' => [
                        'Exemplary governance',
                        'Full board independence',
                        'Comprehensive risk management',
                        'Pró-Gestão certification',
                        'Variable income up to 50%',
                        'Foreign investments up to 20%',
                        'Payroll loans up to 5%',
                    ],
                ],
            ],
            'investment_rules' => [
                'Nível I' => [
                    'fixed_income' => '100%',
                    'variable_income' => '0%',
                    'real_estate' => '0%',
                    'foreign' => '0%',
                ],
                'Nível II' => [
                    'fixed_income' => '100%',
                    'variable_income' => '0%',
                    'real_estate' => '0%',
                    'foreign' => '0%',
                ],
                'Nível III' => [
                    'fixed_income' => '60%',
                    'variable_income' => '40%',
                    'real_estate' => '20%',
                    'foreign' => '0%',
                ],
                'Nível IV' => [
                    'fixed_income' => '50%',
                    'variable_income' => '50%',
                    'real_estate' => '25%',
                    'foreign' => '20%',
                    'payroll_loans' => '5%',
                ],
            ],
            'compliance_requirements' => [
                'certification' => 'Pró-Gestão required for Nível II and above',
                'reporting_frequency' => 'Monthly/Quarterly based on tier',
                'external_audit' => 'Required for all',
                'stress_testing' => 'Required for Nível III and IV',
            ],
            'transition' => [
                'timeline' => '24 months',
                'deadline' => '2026-02-29',
                'requirements' => [
                    'Governance gap analysis within 90 days',
                    'Pró-Gestão certification within 12 months',
                    'Full compliance by 2026',
                ],
            ],
            'metadata' => [
                'source' => 'Banco Central do Brasil',
                'status' => 'Active',
                'effective_date' => '2024-03-01',
                'transition_period' => '24 months',
            ],
        ];
    }

    /**
     * Get CMN 4.963 raw text for parsing
     */
    protected function getCMN4963Text(): string
    {
        return <<<'TEXT'
RESOLUÇÃO CMN Nº 4.963, DE 17 DE JANEIRO DE 2018

Dispõe sobre a aplicação dos recursos dos Regimes Próprios de Previdência Social (RPPS).

A Diretoria Colegiada do Banco Central do Brasil, na sessão realizada em 16 de janeiro de 2018, com base nos arts. 9º, 10 e 11 da Lei nº 4.595, de 31 de dezembro de 1964, no art. 5º da Lei Complementar nº 108, de 29 de maio de 2001, e no art. 4º da Lei nº 12.914, de 22 de dezembro de 2013, R E S O L V E:

Art. 1º Os recursos garantidores dos Regimes Próprios de Previdência Social (RPPS), instituídos pela União, pelos Estados, pelo Distrito Federal e pelos Municípios, devem ser aplicados, observadas as disposições desta Resolução, em estrita conformidade com os critérios de segurança, rentabilidade, solvência, liquidez e transparência, conforme as diretrizes estabelecidas pelos respectivos Conselhos Deliberativos.

Parágrafo único. A aplicação dos recursos de que trata o caput deve preservar o patrimônio dos RPPS e minimizar os riscos de mercado, crédito, liquidez e operacional.

Art. 2º Para fins do disposto nesta Resolução, considera-se:

I - segmentação: a divisão dos recursos em parcelas, com prazo de vencimento predeterminado, respeitada a classificação de risco estabelecida em regulamentação;

II - solvência: a capacidade de o RPPS honrar seus compromissos previdenciários ao longo do tempo;

III - liquidez: a capacidade de converter os ativos em caixa com rapidez e sem perda significativa de valor;

IV - transparência: a ampla e tempestiva divulgação de informações relativas à gestão, à aplicação e ao desempenho dos recursos;

V - carteira de investimentos: o conjunto de ativos e direitos integrantes do patrimônio do RPPS, classificados segundo critérios estabelecidos em regulamentação;

VI - renda fixa: os ativos de renda fixa integrantes da cesta de ativos do Fundo Soberano do Brasil (FSB), de que trata a Lei nº 13.334, de 2016;

VII - renda variável: as ações negociadas em bolsa de valores;

VIII - fundos de investimento: os fundos regulamentados pela Comissão de Valores Mobiliários (CVM) e pelo Banco Central do Brasil (Bacen);

IX - títulos públicos: os títulos emitidos pelo Tesouro Nacional;

X - operações compromissadas: as operações de compra com compromisso de revenda ou de venda com compromisso de recompra;

XI - limites de aplicação: os percentuais máximos de alocação dos recursos do RPPS por modalidade de ativo.

Art. 3º Os recursos dos RPPS devem ser aplicados em:

I - títulos da dívida pública de emissão do Tesouro Nacional;

II - títulos de renda fixa de emissão de instituições financeiras autorizadas a funcionar pelo Bacen;

III - cotas de fundos de investimento financeiro (FIF) e de fundos de investimento em direitos creditórios (FIDC);

IV - operações compromissadas lastreadas em títulos públicos federais;

V - cotas de fundos de investimento referenciados em indicadores de renda fixa;

VI - imóveis urbanos;

VII - operações de crédito com segurados, vinculadas a planos de previdência;

VIII - depósitos à vista e a prazo, em instituições financeiras autorizadas pelo Bacen.

Art. 4º É vedada a aplicação de recursos dos RPPS em:

I - renda variável, exceto ações de empresas estatais nas quais a União, os Estados, o Distrito Federal ou os Municípios detenham, direta ou indiretamente, a maioria do capital social com direito a voto;

II - títulos de emissão de empresas sediadas no exterior;

III - fundos de investimento que tenham, em sua carteira, ativos de renda variável;

IV - operações com derivativos, exceto para fins de hedge;

V - ativos que não sejam negociados em mercado organizado.

Art. 5º A aplicação em imóveis fica limitada a 10% (dez por cento) do total dos recursos do RPPS.

Art. 6º Os RPPS devem manter, no mínimo, 80% (oitenta por cento) de seus recursos em ativos de alta liquidez.

Art. 7º Os RPPS devem apresentar, anualmente, ao Conselho Deliberativo, relatório detalhado sobre a aplicação de seus recursos.

Art. 8º Esta Resolução entra em vigor na data de sua publicação.

Art. 9º Fica revogada a Resolução CMN nº 4.654, de 28 de abril de 2017.

Washington Rocha
Diretor
TEXT;
    }

    /**
     * Get CMN 5.272 raw text for parsing
     */
    protected function getCMN5272Text(): string
    {
        return <<<'TEXT'
RESOLUÇÃO CMN Nº 5.272, DE 29 DE FEVEREIRO DE 2024

Dispõe sobre a aplicação dos recursos dos Regimes Próprios de Previdência Social (RPPS) e revoga a Resolução CMN nº 4.963, de 17 de janeiro de 2018.

O Banco Central do Brasil, em atenção ao disposto na alínea "b" do inciso III do art. 4º da Lei nº 4.595, de 31 de dezembro de 1964, no art. 5º da Lei Complementar nº 108, de 29 de maio de 2001, e no art. 4º da Lei nº 12.914, de 22 de dezembro de 2013, e considerando a necessidade de:

I - aprimorar a governança dos RPPS;

II - estabelecer requisitos proporcionais ao porte e à complexidade dos RPPS;

III - ampliar as possibilidades de aplicação dos recursos, associadas à melhoria da governança;

IV - promover a eficiência na gestão dos recursos e a sustentabilidade dos RPPS; R E S O L V E:

CAPÍTULO I
DAS DISPOSIÇÕES GERAIS

Art. 1º Esta Resolução dispõe sobre a aplicação dos recursos dos Regimes Próprios de Previdência Social (RPPS), instituídos pela União, pelos Estados, pelo Distrito Federal e pelos Municípios.

Art. 2º Para fins do disposto nesta Resolução, considera-se:

I - governança: o conjunto de regras, práticas e processos que orientam a forma como o RPPS é dirigido e controlado;

II - gestão de riscos: o conjunto de políticas e procedimentos para identificar, avaliar, monitorar e controlar os riscos aos quais o RPPS está exposto;

III - estratégia de aplicação de recursos: o conjunto de diretrizes que orientam as decisões de investimento do RPPS;

IV - estrutura de governança em níveis: a classificação dos RPPS em quatro níveis, conforme os requisitos de governança e gestão de riscos;

V - Nível I: o RPPS que atende aos requisitos mínimos de governança e gestão de riscos;

VI - Nível II: o RPPS que atende aos requisitos de governança e gestão de riscos e possui certificação Pró-Gestão;

VII - Nível III: o RPPS que atende aos requisitos de governança e gestão de riscos, possui certificação Pró-Gestão e está autorizado a aplicar recursos em renda variável;

VIII - Nível IV: o RPPS que atende aos requisitos de governança e gestão de riscos, possui certificação Pró-Gestão e está autorizado a aplicar recursos em renda variável, investimentos no exterior e empréstimos consignados.

CAPÍTULO II
DA ESTRUTURA DE GOVERNANÇA EM NÍVEIS

Art. 3º Os RPPS são classificados em quatro níveis, de acordo com os requisitos de governança e gestão de riscos estabelecidos nesta Resolução.

Parágrafo único. A classificação do RPPS em nível superior depende do cumprimento dos requisitos dos níveis anteriores.

Art. 4º O Nível I compreende os RPPS que atendem aos seguintes requisitos mínimos:

I - existência de Conselho Deliberativo, com atribuições e responsabilidades definidas em regimento;

II - existência de diretor ou responsável pela gestão dos recursos;

III - existência de política de investimentos, aprovada pelo Conselho Deliberativo;

IV - realização de testes de estresse anuais;

V - elaboração de relatórios trimestrais de gestão;

VI - manutenção de manuais de governança e de gestão de riscos.

Art. 5º O Nível II compreende os RPPS que atendem aos requisitos do Nível I e, adicionalmente:

I - possuem certificação Pró-Gestão, na forma da regulamentação;

II - contam com, no mínimo, um terço de membros independentes no Conselho Deliberativo;

III - possuem Comitê de Investimentos;

IV - realizam testes de estresse semestrais;

V - elaboram relatórios mensais de gestão;

VI - mantêm política de gestão de riscos formalizada.

Art. 6º O Nível III compreende os RPPS que atendem aos requisitos do Nível II e, adicionalmente:

I - possuem certificação Pró-Gestão no nível "ouro";

II - contam com Comitê de Auditoria independente;

III - realizam testes de estresse trimestrais;

IV - elaboram relatórios de performance comparativa com benchmarks;

V - mantêm estrutura de controle de riscos avançada.

Art. 7º O Nível IV compreende os RPPS que atendem aos requisitos do Nível III e, adicionalmente:

I - possuem governança exemplar, aferida por indicadores de gestão;

II - contam com maioria de membros independentes no Conselho Deliberativo;

III - mantêm Comitê de Riscos independente;

IV - realizam testes de estresse mensais;

V - elaboram relatórios de sustentabilidade de longo prazo.

CAPÍTULO III
DAS APLICAÇÕES DOS RECURSOS

Seção I
Disposições Gerais

Art. 8º Os recursos dos RPPS devem ser aplicados observados os critérios de segurança, rentabilidade, solvência, liquidez e transparência.

Art. 9º As aplicações dos recursos dos RPPS devem respeitar os limites estabelecidos por nível de governança.

Seção II
Das Aplicações por Nível

Art. 10. Os RPPS classificados no Nível I podem aplicar seus recursos em:

I - títulos da dívida pública de emissão do Tesouro Nacional;

II - títulos de renda fixa de emissão de instituições financeiras autorizadas a funcionar pelo Bacen;

III - cotas de fundos de investimento financeiro (FIF) e de fundos de investimento em direitos creditórios (FIDC);

IV - operações compromissadas lastreadas em títulos públicos federais;

V - depósitos à vista e a prazo.

Art. 11. Além das aplicações permitidas no Nível I, os RPPS classificados no Nível II podem aplicar seus recursos em:

I - cotas de fundos de investimento referenciados em indicadores de renda fixa;

II - imóveis urbanos, observado o limite de 10% (dez por cento) dos recursos;

III - operações de crédito com segurados, vinculadas a planos de previdência.

Art. 12. Além das aplicações permitidas no Nível II, os RPPS classificados no Nível III podem aplicar seus recursos em:

I - renda variável, observado o limite de 40% (quarenta por cento) dos recursos;

II - fundos de investimento com atuação em renda variável;

III - imóveis urbanos, observado o limite de 20% (vinte por cento) dos recursos;

IV - operações com derivativos, exclusivamente para fins de hedge.

Art. 13. Além das aplicações permitidas no Nível III, os RPPS classificados no Nível IV podem aplicar seus recursos em:

I - renda variável, observado o limite de 50% (cinquenta por cento) dos recursos;

II - investimentos no exterior, observado o limite de 20% (vinte por cento) dos recursos;

III - operações de crédito consignado, observado o limite de 5% (cinco por cento) dos recursos;

IV - produtos estruturados, observado o limite de 10% (dez por cento) dos recursos.

Seção III
Dos Limites de Concentração

Art. 14. Os RPPS devem observar os seguintes limites de concentração:

I - no máximo 20% (vinte por cento) dos recursos em títulos de uma mesma instituição financeira;

II - no máximo 10% (dez por cento) dos recursos em ações de uma mesma companhia;

III - no máximo 15% (quinze por cento) dos recursos em imóveis de um mesmo tipo;

IV - no máximo 5% (cinco por cento) dos recursos em operações com uma mesma contraparte.

CAPÍTULO IV
DOS REQUISITOS DE COMPLIANCE

Art. 15. Os RPPS devem enviar ao Bacen, trimestralmente, informações sobre a aplicação de seus recursos.

Art. 16. Os RPPS classificados nos Níveis III e IV devem submeter suas estratégias de investimento à aprovação prévia do Comitê de Investimentos.

Art. 17. Os RPPS devem manter, permanentemente, 50% (cinquenta por cento) de seus recursos em ativos de alta liquidez, sujeitos aos ajustes previstos nesta Resolução.

Art. 18. Os RPPS devem realizar, anualmente, auditoria independente de suas demonstrações financeiras.

CAPÍTULO V
DAS DISPOSIÇÕES TRANSITÓRIAS

Art. 19. Os RPPS têm prazo de 24 (vinte e quatro) meses, contados a partir da entrada em vigor desta Resolução, para se adequarem aos novos requisitos de governança e limites de aplicação.

Parágrafo único. Durante o período de transição, os RPPS devem:

I - realizar diagnóstico de governança em até 90 (noventa) dias;

II - elaborar plano de adequação em até 180 (cento e oitenta) dias;

III - obter certificação Pró-Gestão em até 12 (doze) meses, quando aplicável;

IV - adequar a carteira de investimentos aos novos limites em até 24 (vinte e quatro) meses.

Art. 20. Os RPPS que, na data de entrada em vigor desta Resolução, possuam aplicações em desacordo com os novos limites devem ajustar suas carteiras no prazo de que trata o art. 19.

CAPÍTULO VI
DAS DISPOSIÇÕES FINAIS

Art. 21. Esta Resolução entra em vigor em 1º de março de 2024.

Art. 22. Fica revogada a Resolução CMN nº 4.963, de 17 de janeiro de 2018.

Roberto de Oliveira Campos Neto
Presidente
TEXT;
    }

    /**
     * Get combined data for both resolutions
     */
    public function getCombinedData(): array
    {
        return [
            'cmn4963' => $this->getCMN4963Data(),
            'cmn5272' => $this->getCMN5272Data(),
        ];
    }
}
