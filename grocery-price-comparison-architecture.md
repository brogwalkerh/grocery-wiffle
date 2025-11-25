# Grocery Price Comparison App — Responsible Scraping Architecture

## Target Selection

Start with the easiest, most valuable sources:

| Source | Why | Difficulty |
|--------|-----|------------|
| Flipp / WeeklyAds2 | Aggregates circulars from dozens of chains | Low |
| Walmart | Huge market share, prices visible without login | Medium |
| Target | Same-day pricing, Circle offers | Medium |
| Kroger family | Ralphs, Fred Meyer, etc. — also has official API | Medium |
| Instacart (no login) | Multi-store in one place | Higher (bot detection) |

---

## Core Principles

### Be a good neighbor:
- 1-2 requests per second max (human browsing speed)
- Scrape during off-peak hours (2-6 AM)
- Cache aggressively — prices don't change hourly
- Back off immediately on 429s or 5xx errors

### Be transparent (optional but ethical):
```
User-Agent: GroceryCompareBot/1.0 (contact@yourdomain.com; price-transparency-project)
```

---

## High-Level Architecture

```
┌─────────────────┐
│  Scraper Fleet  │  (Python + Playwright, distributed)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Raw Storage   │  (S3/filesystem — store HTML snapshots)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     Parser      │  (Extract product name, price, size, UPC)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Product Matcher │  (THE HARD PART — normalize across stores)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Price Database │  (Postgres — product, store, price, timestamp, ZIP)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Comparison    │  (API/UI layer)
│      API        │
└─────────────────┘
```

---

## The Hard Problem: Product Matching

This is where most grocery comparison apps die. Examples:

- "Cheerios 10.8oz" vs "Cheerios Family Size" vs "General Mills Cheerios"
- Store brands (Great Value vs Kirkland vs Market Pantry)
- Pack sizes, unit pricing

### Approaches:

1. **UPC matching** — If you can extract barcodes, this is gold. Universal identifier.

2. **Fuzzy matching + manual curation** — Start with string similarity (Levenshtein, cosine on TF-IDF), then build a manual mapping table for common items.

3. **Unit price normalization** — Convert everything to $/oz or $/count for comparison even when pack sizes differ.

4. **Start narrow** — Don't try to match 50,000 SKUs. Start with the top 200 grocery staples (milk, eggs, bread, bananas, chicken breast, etc.).

---

## Tech Stack Suggestion

| Layer | Technology | Notes |
|-------|------------|-------|
| Scrapers | Python + Playwright | Handles JS rendering |
| Queue | Redis or Postgres job table | Simple is fine for MVP |
| Database | Postgres with PostGIS | Location-based queries |
| Backend API | Spring Boot (Java) or FastAPI (Python) | Your choice based on comfort |
| Proxies | BrightData, Oxylabs | ~$50-100/month if scaling |

---

## Update Cadence

| Data Type | Frequency |
|-----------|-----------|
| Weekly ads/circulars | Once per week (when they publish) |
| Base prices | Every 2-3 days |
| Sale/promo prices | Daily |

---

## MVP Scope

For a first pass:

1. Pick 3 stores in San Diego (Walmart, Ralphs, Target)
2. Scrape 50 staple items
3. Manual product matching table
4. Simple web UI: paste a list, see totals per store

---

## Legal Considerations

### Supporting Case Law:

- **hiQ v. LinkedIn (9th Circuit, 2022)** — Public data scraping is not "unauthorized access" under CFAA
- **Van Buren v. United States (Supreme Court, 2021)** — Narrowed CFAA to systems you have no right to access at all

### Ethical Justification:

- Price transparency is a public good
- You're reading what stores publicly display
- No authentication bypass, no credential theft
- Rate limiting respects their infrastructure
- Consumers benefit from informed purchasing decisions

---

## Database Schema (Draft)

```sql
-- Stores
CREATE TABLE stores (
    id SERIAL PRIMARY KEY,
    chain VARCHAR(100) NOT NULL,
    name VARCHAR(200),
    address TEXT,
    zip_code VARCHAR(10),
    location GEOGRAPHY(POINT, 4326),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Canonical products (your normalized product list)
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    category VARCHAR(100),
    unit VARCHAR(20),  -- 'oz', 'count', 'lb', etc.
    created_at TIMESTAMP DEFAULT NOW()
);

-- Store-specific product listings
CREATE TABLE store_products (
    id SERIAL PRIMARY KEY,
    store_id INT REFERENCES stores(id),
    product_id INT REFERENCES products(id),
    store_sku VARCHAR(100),
    upc VARCHAR(20),
    store_product_name VARCHAR(300),  -- Their exact name
    size_value DECIMAL(10,2),
    size_unit VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Price history
CREATE TABLE prices (
    id SERIAL PRIMARY KEY,
    store_product_id INT REFERENCES store_products(id),
    price DECIMAL(10,2) NOT NULL,
    unit_price DECIMAL(10,4),  -- $/oz or $/count
    is_sale BOOLEAN DEFAULT FALSE,
    sale_end_date DATE,
    scraped_at TIMESTAMP DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX idx_prices_store_product ON prices(store_product_id, scraped_at DESC);
CREATE INDEX idx_stores_zip ON stores(zip_code);
CREATE INDEX idx_stores_location ON stores USING GIST(location);
```

---

## Next Steps

1. [ ] Set up Playwright scraper for Walmart product pages
2. [ ] Build parser to extract price, name, size, UPC
3. [ ] Create initial list of 50 staple products
4. [ ] Manual product matching for MVP
5. [ ] Simple FastAPI backend with comparison endpoint
6. [ ] Basic React frontend for list input
