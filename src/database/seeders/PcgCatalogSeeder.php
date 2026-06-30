<?php

namespace Database\Seeders;

use App\Models\PcGamer\PcgBuildPreset;
use App\Models\PcGamer\PcgComponentCategory;
use App\Models\PcGamer\PcgRetailer;
use App\Models\PcGamer\PcgTelegramSource;
use Illuminate\Database\Seeder;

class PcgCatalogSeeder extends Seeder
{
    public function run(): void
    {
        $categories = [
            ['slug' => 'gabinete', 'name' => 'Gabinete', 'sort_order' => 10],
            ['slug' => 'motherboard', 'name' => 'Placa-mãe', 'sort_order' => 20],
            ['slug' => 'memoria_ddr5', 'name' => 'Memória DDR5', 'sort_order' => 30],
            ['slug' => 'nvme', 'name' => 'SSD NVMe', 'sort_order' => 40],
            ['slug' => 'placa_video', 'name' => 'Placa de vídeo', 'sort_order' => 50],
            ['slug' => 'processador', 'name' => 'Processador', 'sort_order' => 25],
            ['slug' => 'water_cooler', 'name' => 'Water cooler', 'sort_order' => 60],
            ['slug' => 'fan', 'name' => 'Fans', 'sort_order' => 70],
            ['slug' => 'fonte', 'name' => 'Fonte', 'sort_order' => 80],
            ['slug' => 'suporte_vga', 'name' => 'Suporte/conector VGA', 'sort_order' => 90],
        ];

        foreach ($categories as $category) {
            PcgComponentCategory::query()->updateOrCreate(
                ['slug' => $category['slug']],
                $category
            );
        }

        $retailers = [
            ['slug' => 'meupc', 'name' => 'MEUPC.NET', 'website' => 'https://meupc.net', 'configurator_url' => 'https://meupc.net/build', 'is_aggregator' => true, 'notes' => 'Agregador multi-loja; compare preços KaBuM/Pichau/Terabyte'],
            ['slug' => 'kabum', 'name' => 'KaBuM!', 'website' => 'https://www.kabum.com.br', 'configurator_url' => 'https://www.kabum.com.br/monte-seu-pc', 'is_aggregator' => false, 'notes' => 'Valida soquete, RAM, gabinete e wattagem da fonte'],
            ['slug' => 'pichau', 'name' => 'Pichau', 'website' => 'https://www.pichau.com.br', 'configurator_url' => 'https://www.pichau.com.br/monte-seu-pc', 'is_aggregator' => false, 'notes' => 'Wizard passo a passo; config personalizada não vai montada'],
            ['slug' => 'terabyte', 'name' => 'Terabyteshop', 'website' => 'https://www.terabyteshop.com.br', 'configurator_url' => 'https://www.terabyteshop.com.br/pc-gamer/full-custom', 'is_aggregator' => false, 'notes' => 'Full Custom por plataforma AM5/LGA1700; montagem certificada'],
            ['slug' => 'rocketz', 'name' => 'Rocketz', 'website' => 'https://rocketz.com.br', 'configurator_url' => 'https://rocketz.com.br/monte-seu-pc', 'is_aggregator' => false, 'notes' => 'Configurador visual com preço em tempo real'],
            ['slug' => 'studiopc', 'name' => 'StudioPC', 'website' => 'https://www.studiopc.com.br', 'configurator_url' => null, 'is_aggregator' => false, 'notes' => 'PCs pré-configurados com opcionais (memória, SSD, cooler)'],
            ['slug' => 'pcbuilder', 'name' => 'PC Builder SP', 'website' => 'https://pcbuilder.com.br', 'configurator_url' => 'https://pcbuilder.com.br/build-personalizada', 'is_aggregator' => false, 'notes' => 'Orçamento consultivo + montagem presencial Moema'],
            ['slug' => 'mercadolivre', 'name' => 'Mercado Livre', 'website' => 'https://www.mercadolivre.com.br', 'configurator_url' => 'https://lista.mercadolivre.com.br', 'is_aggregator' => false, 'notes' => 'Marketplace — API pública MLB/search para automação de preços'],
            ['slug' => 'aliexpress', 'name' => 'AliExpress', 'website' => 'https://pt.aliexpress.com', 'configurator_url' => 'https://pt.aliexpress.com', 'is_aggregator' => false, 'notes' => 'Importação — API afiliados IOP ou busca wholesale (pode exigir captcha)'],
            ['slug' => '4gamers', 'name' => '4Gamers', 'website' => 'https://www.4gamers.com.br', 'configurator_url' => 'https://www.4gamers.com.br/monte-seu-computador', 'is_aggregator' => false, 'notes' => 'Monte seu computador — linhas Starter/Action/Power/Colosseum'],
        ];

        foreach ($retailers as $retailer) {
            PcgRetailer::query()->updateOrCreate(
                ['slug' => $retailer['slug']],
                $retailer
            );
        }

        foreach ($this->buildPresets() as $preset) {
            PcgBuildPreset::query()->updateOrCreate(
                ['slug' => $preset['slug']],
                $preset
            );
        }

        foreach (config('pcgamer.telegram.monitor_chats', []) as $chatKey) {
            PcgTelegramSource::query()->updateOrCreate(
                ['chat_key' => $chatKey],
                ['title' => ltrim($chatKey, '@'), 'enabled' => true]
            );
        }
    }

    /**
     * Presets espelhando projects/pc-gamer-cotacoes/src/catalog/presets.py
     *
     * @return list<array<string, mixed>>
     */
    private function buildPresets(): array
    {
        $raw = [
            [
                'slug' => 'amd-entry-7600-4060',
                'name' => 'AMD Entry — Ryzen 5 7600 + RTX 4060',
                'tier' => 'entry',
                'platform' => 'amd_am5',
                'reference_site' => 'terabyte',
                'description' => '1080p alto; referência Terabyte AM5 entry / Pichau custo-benefício',
                'items_json' => [
                    ['category_slug' => 'processador', 'label' => 'AMD Ryzen 5 7600', 'reference_cents' => 89900],
                    ['category_slug' => 'motherboard', 'label' => 'ASRock B650M Pro RS', 'reference_cents' => 79900],
                    ['category_slug' => 'memoria_ddr5', 'label' => '16GB DDR5 5600 (2x8)', 'reference_cents' => 34900],
                    ['category_slug' => 'placa_video', 'label' => 'RTX 4060 8GB', 'reference_cents' => 219900],
                    ['category_slug' => 'nvme', 'label' => 'NVMe 1TB Gen4', 'reference_cents' => 39900],
                    ['category_slug' => 'gabinete', 'label' => 'Gabinete mid tower airflow', 'reference_cents' => 24900],
                    ['category_slug' => 'fonte', 'label' => 'Fonte 650W 80+ Bronze', 'reference_cents' => 34900],
                    ['category_slug' => 'water_cooler', 'label' => 'Cooler tower 120mm', 'reference_cents' => 12900],
                    ['category_slug' => 'fan', 'label' => 'Kit 3x120mm PWM', 'reference_cents' => 9900],
                    ['category_slug' => 'suporte_vga', 'label' => 'Bracket anti-sag', 'reference_cents' => 4900],
                ],
            ],
            [
                'slug' => 'amd-mid-7800x3d-5070',
                'name' => 'AMD Mid — 7800X3D + RTX 5070',
                'tier' => 'mid',
                'platform' => 'amd_am5',
                'reference_site' => 'kabum',
                'description' => '1440p ultra; perfil KaBuM Monte seu PC + MEUPC compare',
                'items_json' => [
                    ['category_slug' => 'processador', 'label' => 'AMD Ryzen 7 7800X3D', 'reference_cents' => 189900],
                    ['category_slug' => 'motherboard', 'label' => 'MSI B650 Tomahawk WiFi', 'reference_cents' => 129900],
                    ['category_slug' => 'memoria_ddr5', 'label' => '32GB DDR5 6000 CL30 (2x16)', 'reference_cents' => 89900],
                    ['category_slug' => 'placa_video', 'label' => 'RTX 5070 12GB', 'reference_cents' => 429900],
                    ['category_slug' => 'nvme', 'label' => 'Samsung 990 EVO Plus 1TB', 'reference_cents' => 54900],
                    ['category_slug' => 'gabinete', 'label' => 'Gabinete airflow vidro temperado', 'reference_cents' => 39900],
                    ['category_slug' => 'fonte', 'label' => 'Fonte 750W 80+ Gold modular', 'reference_cents' => 54900],
                    ['category_slug' => 'water_cooler', 'label' => 'AIO 240mm', 'reference_cents' => 39900],
                    ['category_slug' => 'fan', 'label' => '3x120mm ARGB extra', 'reference_cents' => 14900],
                    ['category_slug' => 'suporte_vga', 'label' => 'Suporte VGA 3 fans RGB', 'reference_cents' => 8900],
                ],
            ],
            [
                'slug' => 'amd-high-7900x-5080',
                'name' => 'AMD High — 7900X + RTX 5080',
                'tier' => 'high',
                'platform' => 'amd_am5',
                'reference_site' => 'studiopc',
                'description' => '4K jogos + stream; inspiração StudioPC Supreme / Terabyte Full Custom',
                'items_json' => [
                    ['category_slug' => 'processador', 'label' => 'AMD Ryzen 9 7900X', 'reference_cents' => 249900],
                    ['category_slug' => 'motherboard', 'label' => 'ASUS TUF X670E-PLUS WiFi', 'reference_cents' => 199900],
                    ['category_slug' => 'memoria_ddr5', 'label' => '32GB DDR5 6400 (2x16)', 'reference_cents' => 109900],
                    ['category_slug' => 'placa_video', 'label' => 'RTX 5080 16GB', 'reference_cents' => 699900],
                    ['category_slug' => 'nvme', 'label' => 'Samsung 990 Pro 1TB', 'reference_cents' => 69900],
                    ['category_slug' => 'gabinete', 'label' => 'Gabinete premium airflow', 'reference_cents' => 59900],
                    ['category_slug' => 'fonte', 'label' => 'Fonte 850W 80+ Gold ATX 3.0', 'reference_cents' => 79900],
                    ['category_slug' => 'water_cooler', 'label' => 'AIO 360mm', 'reference_cents' => 59900],
                    ['category_slug' => 'fan', 'label' => 'Pack fans extra 140mm', 'reference_cents' => 19900],
                    ['category_slug' => 'suporte_vga', 'label' => 'Suporte VGA reforçado', 'reference_cents' => 12900],
                ],
            ],
            [
                'slug' => 'amd-enthusiast-9950x-5090',
                'name' => 'AMD Enthusiast — 9950X3D + RTX 5090',
                'tier' => 'enthusiast',
                'platform' => 'amd_am5',
                'reference_site' => 'terabyte',
                'description' => 'Topo AM5; Terabyte Ryzen 9000 Full Custom',
                'items_json' => [
                    ['category_slug' => 'processador', 'label' => 'AMD Ryzen 9 9950X3D', 'reference_cents' => 399900],
                    ['category_slug' => 'motherboard', 'label' => 'Gigabyte X870E AORUS Elite', 'reference_cents' => 249900],
                    ['category_slug' => 'memoria_ddr5', 'label' => '64GB DDR5 6000 (2x32)', 'reference_cents' => 189900],
                    ['category_slug' => 'placa_video', 'label' => 'RTX 5090 32GB', 'reference_cents' => 1499900],
                    ['category_slug' => 'nvme', 'label' => 'Samsung 990 Pro 2TB', 'reference_cents' => 119900],
                    ['category_slug' => 'gabinete', 'label' => 'Gabinete full tower premium', 'reference_cents' => 89900],
                    ['category_slug' => 'fonte', 'label' => 'Fonte 1200W 80+ Platinum ATX 3.1', 'reference_cents' => 149900],
                    ['category_slug' => 'water_cooler', 'label' => 'AIO 360mm display', 'reference_cents' => 99900],
                    ['category_slug' => 'fan', 'label' => 'Fans premium pack', 'reference_cents' => 29900],
                    ['category_slug' => 'suporte_vga', 'label' => 'Suporte VGA + cable combs', 'reference_cents' => 15900],
                ],
            ],
        ];

        return array_map(function (array $preset): array {
            $preset['total_reference_cents'] = array_sum(
                array_column($preset['items_json'], 'reference_cents')
            );

            return $preset;
        }, $raw);
    }
}
