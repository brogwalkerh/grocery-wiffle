# GroceryCompare Mobile App

A **self-contained** cross-platform mobile application for comparing grocery prices across local stores using **real-time API data**.

## Features

- **Grocery List Management**: Create and manage multiple shopping lists locally
- **Live Price Comparison**: Search real grocery prices from major retailers
- **Real-Time Search**: Look up any grocery item on the fly
- **Offline Lists**: Your grocery lists are stored locally on your device
- **Location-Based**: Find stores near your ZIP code
- **No Backend Required**: Works as a standalone app - no server needed!

## Supported Stores

Currently supported through the Kroger API (covers 2,800+ stores):
- Kroger
- Ralphs
- Fred Meyer
- Fry's Food
- King Soopers
- Smith's
- QFC
- Mariano's
- Pick 'n Save
- Metro Market
- And more Kroger family stores...

## Setup - API Configuration

To enable live price searching, you need to configure the Kroger API (free):

### 1. Get Kroger API Credentials

1. Go to [developer.kroger.com](https://developer.kroger.com)
2. Click "Create an Account" and sign up (it's free)
3. Go to "Manage Apps" and click "Register App"
4. Fill in app details (any name is fine)
5. Copy your **Client ID** and **Client Secret**

### 2. Configure the App

Edit `lib/core/config/grocery_api_config.dart`:

```dart
class GroceryApiConfig {
  static const String krogerClientId = 'YOUR_CLIENT_ID_HERE';
  static const String krogerClientSecret = 'YOUR_CLIENT_SECRET_HERE';
}
```

### 3. Run the App

```bash
cd mobile
flutter pub get
flutter run
```

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
│   ├── services/           # Live search & comparison services
│   ├── datasources/
│   │   └── local/          # Local storage (Hive)
│   └── providers/          # Riverpod providers
├── features/
│   ├── grocery_list/       # Grocery list feature
│   ├── comparison/         # Price comparison feature
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
