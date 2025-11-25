# GroceryCompare Backend API

A FastAPI-based backend service for the GroceryCompare grocery price comparison application.

## Features

- **Grocery List Management**: Create, read, update, and delete grocery lists
- **Price Comparison**: Compare prices across multiple stores for your grocery list
- **Product Matching**: Fuzzy matching for product names and brand variations
- **Caching**: Redis-based caching for price data
- **Database**: PostgreSQL with SQLAlchemy ORM

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
│   │       └── compare.py   # Price comparison endpoint
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
