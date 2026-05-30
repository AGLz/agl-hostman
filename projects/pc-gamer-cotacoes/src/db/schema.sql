-- Catálogo de peças, ofertas Telegram, montagens e efetivações

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS component_categories (
    id INTEGER PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS components (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id INTEGER NOT NULL REFERENCES component_categories(id),
    sku TEXT,
    brand TEXT,
    model TEXT NOT NULL,
    specs_json TEXT NOT NULL DEFAULT '{}',
    notes TEXT,
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_components_category ON components(category_id);
CREATE INDEX IF NOT EXISTS idx_components_brand ON components(brand);

CREATE TABLE IF NOT EXISTS telegram_sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chat_key TEXT NOT NULL UNIQUE,
    title TEXT,
    enabled INTEGER NOT NULL DEFAULT 1,
    last_synced_message_id INTEGER,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS telegram_offers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id INTEGER NOT NULL REFERENCES telegram_sources(id),
    message_id INTEGER NOT NULL,
    message_hash TEXT NOT NULL,
    posted_at TEXT,
    raw_text TEXT NOT NULL,
    parsed_json TEXT NOT NULL DEFAULT '{}',
    product_name TEXT,
    price_cents INTEGER,
    currency TEXT NOT NULL DEFAULT 'BRL',
    url TEXT,
    matched_category_slug TEXT,
    matched_component_id INTEGER REFERENCES components(id),
    status TEXT NOT NULL DEFAULT 'new',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(source_id, message_id),
    UNIQUE(message_hash)
);

CREATE INDEX IF NOT EXISTS idx_offers_category ON telegram_offers(matched_category_slug);
CREATE INDEX IF NOT EXISTS idx_offers_price ON telegram_offers(price_cents);

CREATE TABLE IF NOT EXISTS builds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    customer_name TEXT,
    customer_contact TEXT,
    platform TEXT NOT NULL DEFAULT 'amd',
    status TEXT NOT NULL DEFAULT 'draft',
    margin_percent REAL NOT NULL DEFAULT 15,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_builds_status ON builds(status);

CREATE TABLE IF NOT EXISTS build_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    build_id INTEGER NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    category_slug TEXT NOT NULL,
    component_id INTEGER REFERENCES components(id),
    offer_id INTEGER REFERENCES telegram_offers(id),
    label TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_cost_cents INTEGER NOT NULL DEFAULT 0,
    source TEXT NOT NULL DEFAULT 'manual',
    notes TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_build_items_build ON build_items(build_id);

CREATE TABLE IF NOT EXISTS build_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    build_id INTEGER NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    from_status TEXT,
    to_status TEXT,
    payload_json TEXT NOT NULL DEFAULT '{}',
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_build_events_build ON build_events(build_id);

-- Lojas de referência (configuradores BR)
CREATE TABLE IF NOT EXISTS retailers (
    id INTEGER PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    website TEXT,
    configurator_url TEXT,
    is_aggregator INTEGER NOT NULL DEFAULT 0,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS market_prices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    retailer_id INTEGER NOT NULL REFERENCES retailers(id),
    category_slug TEXT NOT NULL,
    product_name TEXT NOT NULL,
    price_cents INTEGER NOT NULL,
    url TEXT,
    recorded_at TEXT NOT NULL DEFAULT (datetime('now')),
    source TEXT NOT NULL DEFAULT 'manual',
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_market_prices_category ON market_prices(category_slug);
CREATE INDEX IF NOT EXISTS idx_market_prices_retailer ON market_prices(retailer_id);

CREATE TABLE IF NOT EXISTS build_presets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    tier TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'amd_am5',
    reference_site TEXT,
    description TEXT,
    total_reference_cents INTEGER NOT NULL DEFAULT 0,
    items_json TEXT NOT NULL DEFAULT '[]',
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Seeds: categorias de montagem gamer (sem periféricos)
INSERT OR IGNORE INTO component_categories (id, slug, name, sort_order) VALUES
    (1, 'gabinete', 'Gabinete', 10),
    (2, 'motherboard', 'Placa-mãe', 20),
    (3, 'memoria_ddr5', 'Memória DDR5', 30),
    (4, 'nvme', 'SSD NVMe', 40),
    (5, 'placa_video', 'Placa de vídeo', 50),
    (6, 'processador', 'Processador', 25),
    (7, 'water_cooler', 'Water cooler', 60),
    (8, 'fan', 'Fans', 70),
    (9, 'fonte', 'Fonte', 80),
    (10, 'suporte_vga', 'Suporte/conector VGA', 90);

INSERT OR IGNORE INTO retailers (id, slug, name, website, configurator_url, is_aggregator, notes) VALUES
    (1, 'meupc', 'MEUPC.NET', 'https://meupc.net', 'https://meupc.net/build', 1,
     'Agregador multi-loja; compare preços KaBuM/Pichau/Terabyte'),
    (2, 'kabum', 'KaBuM!', 'https://www.kabum.com.br', 'https://www.kabum.com.br/monte-seu-pc', 0,
     'Valida soquete, RAM, gabinete e wattagem da fonte'),
    (3, 'pichau', 'Pichau', 'https://www.pichau.com.br', 'https://www.pichau.com.br/monte-seu-pc', 0,
     'Wizard passo a passo; config personalizada não vai montada'),
    (4, 'terabyte', 'Terabyteshop', 'https://www.terabyteshop.com.br', 'https://www.terabyteshop.com.br/pc-gamer/full-custom', 0,
     'Full Custom por plataforma AM5/LGA1700; montagem certificada'),
    (5, 'rocketz', 'Rocketz', 'https://rocketz.com.br', 'https://rocketz.com.br/monte-seu-pc', 0,
     'Configurador visual com preço em tempo real'),
    (6, 'studiopc', 'StudioPC', 'https://www.studiopc.com.br', NULL, 0,
     'PCs pré-configurados com opcionais (memória, SSD, cooler)'),
    (7, 'pcbuilder', 'PC Builder SP', 'https://pcbuilder.com.br', 'https://pcbuilder.com.br/build-personalizada', 0,
     'Orçamento consultivo + montagem presencial Moema'),
    (8, 'mercadolivre', 'Mercado Livre', 'https://www.mercadolivre.com.br', 'https://lista.mercadolivre.com.br', 0,
     'Marketplace — API pública MLB/search para automação de preços'),
    (9, 'aliexpress', 'AliExpress', 'https://pt.aliexpress.com', 'https://pt.aliexpress.com', 0,
     'Importação — API afiliados IOP ou busca wholesale (pode exigir captcha)'),
    (10, '4gamers', '4Gamers', 'https://www.4gamers.com.br', 'https://www.4gamers.com.br/monte-seu-computador', 0,
     'Monte seu computador — linhas Starter/Action/Power/Colosseum');
