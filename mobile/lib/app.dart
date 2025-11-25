import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/grocery_list/presentation/screens/grocery_lists_screen.dart';
import 'features/grocery_list/presentation/screens/grocery_list_detail_screen.dart';
import 'features/comparison/presentation/screens/comparison_screen.dart';
import 'features/settings/settings_screen.dart';

/// Main application widget.
class GroceryCompareApp extends ConsumerWidget {
  const GroceryCompareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'GroceryCompare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}

/// Application router configuration.
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const GroceryListsScreen(),
      routes: [
        GoRoute(
          path: 'list/:id',
          name: 'list-detail',
          builder: (context, state) {
            final listId = state.pathParameters['id']!;
            return GroceryListDetailScreen(listId: listId);
          },
        ),
        GoRoute(
          path: 'compare/:listId',
          name: 'compare',
          builder: (context, state) {
            final listId = state.pathParameters['listId']!;
            return ComparisonScreen(listId: listId);
          },
        ),
        GoRoute(
          path: 'settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
