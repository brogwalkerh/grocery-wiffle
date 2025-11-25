# GroceryCompare Mobile App

A cross-platform mobile application for comparing grocery prices across local stores.

## Features

- **Grocery List Management**: Create and manage multiple shopping lists
- **Price Comparison**: Compare prices across different stores in your area
- **Product Search**: Autocomplete search for products
- **Offline Support**: Access your lists offline with SQLite storage
- **Location Services**: Auto-detect ZIP code or enter manually

## Project Structure

```
lib/
├── main.dart               # Application entry point
├── app.dart                # App configuration and routing
├── core/
│   ├── config/             # API and app configuration
│   ├── theme/              # Material Design 3 theming
│   ├── utils/              # Utility functions
│   └── constants/          # App constants
├── data/
│   ├── models/             # Data models
│   ├── repositories/       # Repository layer
│   ├── datasources/
│   │   ├── local/          # SQLite data sources
│   │   └── remote/         # API data sources
│   └── providers/          # Riverpod providers
├── features/
│   ├── grocery_list/       # Grocery list feature
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   └── widgets/
│   │   └── domain/
│   ├── comparison/         # Price comparison feature
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   └── widgets/
│   │   └── domain/
│   └── settings/           # Settings feature
└── shared/
    └── widgets/            # Shared widgets
```

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart (>=3.0.0)
- iOS Simulator or Android Emulator

### Installation

1. Navigate to the mobile directory:
```bash
cd mobile
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## State Management

This app uses **Riverpod** for state management, providing:
- Compile-time safety
- Easy testing
- Automatic disposal
- Dependency injection

## Architecture

The app follows a clean architecture approach:
- **Presentation Layer**: Screens and widgets using Riverpod for state
- **Domain Layer**: Business logic and use cases
- **Data Layer**: Repositories, data sources, and models

## Theming

The app uses Material Design 3 with:
- Dynamic color support
- Light and dark mode
- Proper contrast ratios for accessibility

## Testing

```bash
flutter test
```

## Building

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## License

MIT
