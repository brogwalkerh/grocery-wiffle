# GroceryCompare - Smart Grocery Price Comparison App

## Overview
A cross-platform mobile app that allows users to input or upload a grocery list, then determines which local grocery store offers the lowest total price. Designed to be affordable/free with a focus on accessibility.

## Target Platforms
- iOS (Swift/SwiftUI)
- Android (Kotlin/Jetpack Compose)
- Consider: Flutter or React Native for shared codebase

## Core Features

### 1. Grocery List Input
- Manual text entry with autocomplete
- Voice input
- Photo/receipt OCR scanning (parse existing receipts or handwritten lists)
- Import from notes apps or shared lists
- Save favorite/recurring lists

### 2. Price Data Aggregation
Data sources (prioritized by reliability):

**Tier 1 - APIs:**
- Kroger API (covers Kroger, Ralphs, Fred Meyer, Smith's, etc.)
- Walmart API (if available)
- Target/Shipt integration

**Tier 2 - Public Data:**
- Weekly digital circulars/ads (PDF parsing from store websites)
- Flipp API or scraping (aggregates weekly ads)
- USDA/BLS average price data for baseline validation
- Google Shopping price surfacing

**Tier 3 - Crowdsourced:**
- User-submitted prices (like GasBuddy model)
- Receipt OCR contributions (users scan receipts to update database)
- Price verification/flagging system

**Tier 4 - Delivery Platforms:**
- Instacart public listings (pre-login)
- Amazon Fresh
- Walmart Grocery

### 3. Product Matching Engine
Critical component - must handle:
- Brand variations ("Cheerios" vs "General Mills Cheerios")
- Size normalization (calculate price-per-unit)
- Generic/store brand equivalents
- UPC/barcode lookups
- Fuzzy string matching with confidence scores

### 4. Price Comparison & Results
- Total cost per store for entire list
- Item-by-item breakdown
- Highlight which items are cheapest where
- "Split trip" optimization (if visiting 2 stores saves $X)
- Factor in distance/gas cost optionally
- Show price history trends

### 5. Location Services
- Auto-detect user location
- Filter to stores within configurable radius
- Store hours and current open/closed status
- Integration with maps for directions

## Technical Architecture

```
grocery-compare/
├── mobile/
│   ├── ios/                    # Native iOS (if not cross-platform)
│   ├── android/                # Native Android (if not cross-platform)
│   └── shared/                 # Flutter/React Native (if cross-platform)
├── backend/
│   ├── api/                    # REST API server
│   │   ├── routes/
│   │   │   ├── lists.py        # Grocery list CRUD
│   │   │   ├── prices.py       # Price queries
│   │   │   ├── stores.py       # Store locations
│   │   │   └── compare.py      # Comparison logic
│   │   └── main.py
│   ├── services/
│   │   ├── price_aggregator.py # Coordinates all data sources
│   │   ├── product_matcher.py  # Fuzzy matching engine
│   │   ├── kroger_client.py    # Kroger API integration
│   │   ├── circular_parser.py  # Weekly ad PDF/HTML parsing
│   │   ├── ocr_service.py      # Receipt/list scanning
│   │   └── cache_manager.py    # Price data caching
│   ├── models/
│   │   ├── product.py
│   │   ├── price.py
│   │   ├── store.py
│   │   └── grocery_list.py
│   └── workers/
│       ├── price_updater.py    # Scheduled price refresh jobs
│       └── circular_fetcher.py # Weekly ad ingestion
├── data/
│   ├── product_catalog.db      # Master product database
│   ├── price_history.db        # Historical prices
│   └── store_locations.json    # Store metadata
├── ml/
│   ├── product_classifier.py   # ML for product matching
│   └── price_predictor.py      # Optional: predict sale patterns
└── docs/
    ├── API.md
    ├── DATA_SOURCES.md
    └── ARCHITECTURE.md
```

## Tech Stack Recommendations

### Backend
- **Language:** Python (FastAPI) or Node.js (Express)
- **Database:** PostgreSQL (products, prices) + Redis (caching)
- **OCR:** Tesseract or Google Vision API
- **Job Queue:** Celery or Bull for background price updates

### Mobile
- **Cross-platform:** Flutter (Dart) or React Native
- **State Management:** Riverpod (Flutter) or Redux (RN)
- **Local Storage:** SQLite for offline list access

### Infrastructure
- Cloud: AWS/GCP/Azure
- Consider serverless for cost efficiency at low scale

## Data Challenges & Solutions

| Challenge | Solution |
|-----------|----------|
| No public APIs | Start with Kroger API + circular parsing |
| Price varies by ZIP | Location-based queries, cache per region |
| Product name mismatches | Fuzzy matching + UPC lookup + ML classifier |
| Data freshness | Daily circular updates, crowdsourced validation |
| Cold start (no data) | Seed with USDA averages, incentivize early users |

## MVP Scope (Phase 1)
1. Manual list input with autocomplete
2. Kroger API integration (single chain to start)
3. Weekly circular parsing for 2-3 major chains
4. Basic store comparison for user's ZIP code
5. Simple results display

## Future Enhancements
- Receipt scanning to auto-build lists
- Price alerts for favorite items
- Meal planning integration
- Coupon/rebate aggregation (Ibotta, store coupons)
- Social features (share lists, group shopping)

## Business Model Options
- Free with ads
- $0.99-$2.99 one-time purchase (ad-free)
- Affiliate links to delivery services
- Premium tier with advanced features

## Development Notes
- Respect robots.txt and ToS when scraping
- Implement rate limiting on external API calls
- Cache aggressively to reduce costs
- Build admin dashboard for data quality monitoring
