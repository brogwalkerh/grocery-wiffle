# Getting Accurate Grocery Price Data - Implementation Guide

## The Challenge

Grocery price data is difficult to obtain because:
1. **Web scraping is unreliable** - Stores change HTML, use bot detection, rate limit
2. **Most APIs are paid/restricted** - Target, Walmart, Amazon require partnerships
3. **Data goes stale quickly** - Prices change weekly with sales

## Our Multi-Layered Strategy

### Layer 1: Flipp Weekly Circulars (Primary - Most Reliable) ⭐

**Why this is best:**
- Stores WANT you to see their ads (no blocking)
- Data is officially published by retailers
- Covers 800+ stores across US/Canada
- Updates weekly with current sales
- Includes BOGO, multi-buy deals

**Implementation:**
- Current: Using public Flipp endpoints (may be rate-limited)
- Recommended: Get Flipp Business API access
- Cost: Contact Flipp for pricing (https://flipp.com/business)

**Stores covered:**
- Walmart, Target, Kroger, Safeway, Albertsons, Publix, H-E-B
- CVS, Walgreens, Rite Aid
- Dollar General, Family Dollar
- And 700+ more regional chains

### Layer 2: Official Store APIs (When Available)

#### Kroger API (FREE - Highly Recommended) ⭐
**Coverage:** Kroger, Ralphs, Fred Meyer, Fry's, King Soopers, QFC, etc.

**Setup (5 minutes):**
1. Go to https://developer.kroger.com/
2. Create account
3. Register application
4. Get Client ID and Secret
5. Add to `.env`:
   ```
   KROGER_CLIENT_ID=your_id
   KROGER_CLIENT_SECRET=your_secret
   ```

**Limits:** 10,000 calls/day (free tier)

**What you get:**
- Real-time prices
- Product availability
- Store locations
- Nutritional data

#### Target RedCircle API (Invite Only)
- Not publicly available
- Requires partnership/invitation
- Skip for now

#### Walmart API (Partnership Required)
- Requires Walmart Marketplace seller account
- Or corporate partnership
- Not accessible for indie developers

### Layer 3: Public Product Databases (FREE)

#### USDA FoodData Central (FREE - Get This Now!) ⭐
**What:** Official US government food database

**Setup (30 seconds):**
1. Visit https://fdc.nal.usda.gov/api-key-signup.html
2. Enter email
3. Get instant API key
4. Add to `.env`:
   ```
   USDA_API_KEY=your_key_here
   ```

**Limits:**
- DEMO_KEY: 25 requests/hour (severely limited)
- Real key: 3,600 requests/hour

**What you get:**
- 350,000+ food products
- Nutritional data
- Some price ranges (from surveys)
- Brand names and descriptions

#### Open Food Facts (FREE - No Key Required)
Already integrated! Provides:
- 2M+ products worldwide
- Community-contributed data
- Product images, barcodes
- Some price data (limited)

### Layer 4: Web Scraping (Fallback Only)

**When to use:** Only when APIs fail or return no results

**Current implementation:**
- Walmart, Target, Kroger, Costco, Aldi scrapers
- Rate limiting to avoid blocks
- User agent rotation
- Graceful timeout handling

**Problems:**
- Gets blocked frequently
- HTML structure changes
- Rate limits
- Legal gray area

## Recommended Implementation Plan

### Phase 1: Quick Wins (Do This Now - 10 minutes)

1. **Get USDA API key** (30 seconds)
   - https://fdc.nal.usda.gov/api-key-signup.html
   - Replace `USDA_API_KEY=DEMO_KEY` in `.env`

2. **Apply for Kroger API** (5 minutes)
   - https://developer.kroger.com/
   - Add credentials to `.env`

3. **Test Flipp integration**
   - Already using public endpoints
   - Monitor for rate limits

### Phase 2: Medium Term (Next Week)

1. **Contact Flipp Business**
   - Request quote for API access
   - Compare vs. public endpoint limitations
   - Implement authentication if approved

2. **Add Google Maps API** (for store locations)
   - https://console.cloud.google.com/
   - $200 free credit monthly
   - Improves zip code → store matching

### Phase 3: Long Term (Optional)

1. **Explore Aggregator Services**
   - Quotient (formerly Coupons.com)
   - Inmar Intelligence
   - Note: These are expensive ($$$ thousands/month)

2. **Partner Programs**
   - Apply for Target, Walmart partnerships
   - Requires business legitimacy
   - May take months for approval

## Alternative Approaches

### Option A: User-Submitted Prices
**Pros:**
- Community-driven
- No API costs
- Legal (user data)

**Cons:**
- Requires user base
- Quality control needed
- Slower data collection

**Example:** GasBuddy model for groceries

### Option B: Receipt Scanning (Future)
**Pros:**
- Accurate real prices
- User engagement
- Automatic data entry

**Cons:**
- OCR complexity
- Privacy concerns
- Requires mobile app permissions

**Implementation:**
- Use Tesseract OCR
- Or Google Cloud Vision API
- Parse structured receipt data

### Option C: Store Loyalty Card APIs
Some stores provide APIs for loyalty card members:
- Safeway/Albertsons Just for U
- CVS ExtraCare
- Walgreens Balance Rewards

**Cons:**
- User must share credentials (risky)
- Terms of service violations
- Account suspension risk

## Data Quality Metrics

Track these to measure accuracy:

```python
metrics = {
    "source": "flipp|kroger|usda|scraping",
    "is_estimate": bool,
    "price_age_hours": int,
    "confidence": float,  # 0.0 - 1.0
}
```

**Prioritize sources:**
1. Flipp weekly circulars (is_estimate=False, confidence=0.95)
2. Kroger API (is_estimate=False, confidence=0.90)
3. Recent scrapes <24hrs (is_estimate=False, confidence=0.70)
4. Old scrapes >24hrs (is_estimate=True, confidence=0.40)
5. USDA estimates (is_estimate=True, confidence=0.30)

## Cost Analysis

### Free Tier (Current)
- Flipp public endpoints: FREE (rate limited)
- Kroger API: FREE (10k calls/day)
- USDA API: FREE (3600 calls/hour)
- Open Food Facts: FREE (unlimited)
- **Total: $0/month**

### Paid Tier (Recommended)
- Flipp Business API: ~$500-2000/month (estimate)
- Google Maps API: ~$50/month (with free credit)
- Everything else: FREE
- **Total: ~$500-2000/month**

### Enterprise Tier
- Add Instacart API (if available)
- Add Quotient/Inmar: $5000+/month
- Add Amazon Product Advertising API
- **Total: $5000+/month**

## Legal Considerations

✅ **Definitely Legal:**
- Official APIs with terms acceptance
- User-submitted data
- Public government databases (USDA)

⚠️ **Gray Area:**
- Web scraping (check robots.txt, ToS)
- Flipp public endpoints (designed for consumers)

❌ **Avoid:**
- Automated account creation
- Scraping with CAPTCHA bypass
- Storing credit card data
- Violating explicit ToS

## Next Steps

1. Copy `.env.example` to `.env`
2. Get USDA API key (30 sec)
3. Apply for Kroger API (5 min)
4. Test current Flipp integration
5. Monitor error rates and data quality
6. Contact Flipp Business for quote
7. Implement fallback strategy improvements

## Support Resources

- **Flipp Business:** business@flipp.com
- **Kroger Developer:** https://developer.kroger.com/support
- **USDA API:** fdc@usda.gov
- **Open Food Facts:** https://slack.openfoodfacts.org/

---

**Bottom Line:** Get the USDA and Kroger API keys TODAY (takes 5 minutes total, both FREE). This will dramatically improve your price data accuracy while you evaluate Flipp Business API pricing.
