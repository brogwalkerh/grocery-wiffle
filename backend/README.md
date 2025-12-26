# GroceryCompare Backend API

A FastAPI-based backend service for the GroceryCompare grocery price comparison application.

## Features

- **Grocery List Management**: Create, read, update, and delete grocery lists
- **Price Comparison**: Compare prices across multiple stores for your grocery list
- **Product Matching**: Fuzzy matching for product names and brand variations
- **Price Crawling**: Background service that crawls store websites for real prices
- **Real-time Updates**: WebSocket support for pushing price updates to mobile app
- **Caching**: Database-backed caching for price data
- **Database**: PostgreSQL with SQLAlchemy ORM (async support)

## Quick Start

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set up environment variables
cp .env.example .env
# Edit .env with your database credentials

# Run database migrations
alembic upgrade head

# Start the server
uvicorn app.main:app --reload
```

The API will be available at http://localhost:8000

- Swagger docs: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Price Crawler

The backend includes a background price crawler that:

1. **Crawls store websites** - Walmart, Target, Kroger, Costco, Aldi
2. **Stores prices in database** - With timestamps for freshness
3. **Schedules regular updates** - Common products crawled every 6 hours
4. **Handles rate limiting** - Respects store website limits

### Scheduler Stats

```bash
curl http://localhost:8000/api/v1/prices/scheduler/stats
```

### Manual Crawl Request

```bash
curl -X POST http://localhost:8000/api/v1/prices/crawl \
  -H "Content-Type: application/json" \
  -d '{"query": "milk", "priority": 1}'
```

## API Endpoints

### Price Endpoints

- `GET /api/v1/prices/search?q=milk` - Search for prices (uses cache, triggers crawl if needed)
- `GET /api/v1/prices/cached?q=milk` - Get cached prices only (fast)
- `POST /api/v1/prices/crawl` - Request a background crawl
- `GET /api/v1/prices/batch-search?products=milk&products=eggs` - Search multiple products
- `GET /api/v1/prices/scheduler/stats` - Get crawler statistics

### WebSocket

Connect to `/ws/prices/{user_id}` for real-time price updates.

```javascript
// Example client
const ws = new WebSocket('ws://localhost:8000/ws/prices/user123');

ws.onopen = () => {
  ws.send(JSON.stringify({
    action: 'subscribe',
    products: ['milk', 'eggs', 'bread']
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  if (data.type === 'price_update') {
    console.log('Price update:', data);
  }
};
```

## Project Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI application entry point
│   ├── config.py            # Application configuration
│   ├── api/
│   │   ├── __init__.py
│   │   ├── deps.py          # Dependency injection
│   │   └── routes/
│   │       ├── __init__.py
│   │       ├── lists.py     # Grocery list CRUD endpoints
│   │       ├── compare.py   # Price comparison endpoint
│   │       ├── prices.py    # Price data endpoints
│   │       └── websocket.py # WebSocket endpoint
│   ├── models/
│   │   ├── __init__.py
│   │   ├── product.py       # Product model
│   │   ├── price.py         # Price model
│   │   ├── store.py         # Store model
│   │   └── grocery_list.py  # Grocery list model
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── product.py       # Product schemas
│   │   ├── price.py         # Price schemas
│   │   ├── store.py         # Store schemas
│   │   └── grocery_list.py  # Grocery list schemas
│   ├── services/
│   │   ├── __init__.py
│   │   ├── product_matcher.py   # Fuzzy matching service
│   │   ├── price_crawler.py     # Price web scraping service
│   │   ├── price_scheduler.py   # Background crawl scheduler
│   │   ├── kroger_client.py     # Kroger API client stub
│   │   └── circular_parser.py   # Weekly ad parser
│   ├── db/
│   │   ├── __init__.py
│   │   ├── database.py      # Database connection
│   │   └── seed.py          # Seed data scripts
│   └── core/
│       ├── __init__.py
│       └── cache.py         # Redis caching
├── tests/
│   ├── __init__.py
│   ├── conftest.py          # Pytest fixtures
│   └── test_product_matcher.py  # Product matcher tests
├── requirements.txt
├── pyproject.toml
└── README.md
```

## Setup

### Prerequisites

- Python 3.10+
- PostgreSQL 13+
- Redis 6+

### Installation

1. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Run the application:
```bash
uvicorn app.main:app --reload
```

## API Endpoints

### Grocery Lists

- `POST /api/lists` - Create a new grocery list
- `GET /api/lists` - Get all grocery lists for a user
- `GET /api/lists/{list_id}` - Get a specific grocery list
- `PUT /api/lists/{list_id}` - Update a grocery list
- `DELETE /api/lists/{list_id}` - Delete a grocery list

### Price Comparison

- `POST /api/compare` - Compare prices for a grocery list across stores

## Testing

```bash
pytest
```

With coverage:
```bash
pytest --cov=app --cov-report=html
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://localhost/grocery_compare` |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379` |
| `KROGER_CLIENT_ID` | Kroger API client ID | - |
| `KROGER_CLIENT_SECRET` | Kroger API client secret | - |
| `DEBUG` | Enable debug mode | `false` |

## License

MIT
