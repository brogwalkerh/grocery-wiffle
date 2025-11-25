# GroceryCompare

A cross-platform grocery price comparison app that helps users find the best prices for their grocery list across local stores.

## Overview

GroceryCompare allows users to:
- Create and manage grocery lists
- Compare prices across multiple local stores
- Find the best deals and potential savings
- Access lists offline with local storage

## Project Structure

```
grocery-wiffle/
├── backend/              # FastAPI backend API
│   ├── app/
│   │   ├── api/          # API routes
│   │   ├── models/       # Database models
│   │   ├── schemas/      # Pydantic schemas
│   │   ├── services/     # Business logic
│   │   ├── db/           # Database configuration
│   │   └── core/         # Core utilities (caching)
│   ├── tests/            # Unit tests
│   └── requirements.txt
├── mobile/               # Flutter mobile app
│   ├── lib/
│   │   ├── core/         # Configuration, theme, utilities
│   │   ├── data/         # Models, repositories, datasources
│   │   ├── features/     # Feature modules
│   │   └── shared/       # Shared widgets
│   └── test/
└── docker-compose.yml    # Local development setup
```

## Backend API (Python/FastAPI)

### Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Run

```bash
uvicorn app.main:app --reload
```

### API Endpoints

- `POST /api/lists` - Create a new grocery list
- `GET /api/lists` - Get all grocery lists for a user
- `GET /api/lists/{list_id}` - Get a specific grocery list
- `PUT /api/lists/{list_id}` - Update a grocery list
- `DELETE /api/lists/{list_id}` - Delete a grocery list
- `POST /api/compare` - Compare prices across stores

### Testing

```bash
cd backend
pytest
```

## Mobile App (Flutter)

### Setup

```bash
cd mobile
flutter pub get
```

### Run

```bash
flutter run
```

### Features

- **Grocery List Management**: Create, edit, and organize shopping lists
- **Price Comparison**: Compare prices across stores in your area
- **Offline Support**: Access lists without internet connection
- **Material Design 3**: Modern, accessible UI

## Docker Development

Run the complete stack with Docker:

```bash
docker-compose up
```

This starts:
- Backend API on http://localhost:8000
- PostgreSQL database on port 5432
- Redis cache on port 6379

## Technology Stack

### Backend
- **Framework**: FastAPI (Python)
- **Database**: PostgreSQL with SQLAlchemy ORM
- **Caching**: Redis
- **Testing**: pytest

### Mobile
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Local Storage**: Hive, SQLite
- **HTTP Client**: Dio

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://localhost/grocery_compare` |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379` |
| `KROGER_CLIENT_ID` | Kroger API client ID | - |
| `KROGER_CLIENT_SECRET` | Kroger API client secret | - |

## Future Enhancements

- Kroger API integration (pending credentials)
- Weekly circular/ad parsing
- Receipt OCR scanning
- Price alerts
- Meal planning integration

## License

MIT

# grocery-wiffle

A repository for apps that use alternative methods of data processing and democratization.
