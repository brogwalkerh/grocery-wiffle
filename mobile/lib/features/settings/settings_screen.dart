import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/providers/providers.dart';

/// Settings screen.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _zipCodeController;

  @override
  void initState() {
    super.initState();
    _zipCodeController = TextEditingController(
      text: ref.read(zipCodeProvider),
    );
  }

  @override
  void dispose() {
    _zipCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Location section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Location',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Default ZIP Code'),
            subtitle: Text(ref.watch(zipCodeProvider)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final newZipCode = await _showZipCodeDialog();
              if (newZipCode != null) {
                ref.read(zipCodeProvider.notifier).state = newZipCode;
              }
            },
          ),

          const Divider(),

          // App Info section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'About',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('About GroceryCompare'),
            subtitle: const Text('Compare grocery prices across stores'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 GroceryCompare',
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'GroceryCompare helps you find the best prices for your '
                    'grocery list across local stores. Simply create a list, '
                    'enter your ZIP code, and compare prices instantly.',
                  ),
                ],
              );
            },
          ),

          const Divider(),

          // Data section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Data',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear Local Data'),
            subtitle: const Text('Remove cached lists and settings'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Data'),
                  content: const Text(
                    'This will remove all locally cached grocery lists '
                    'and settings. Your lists will still be available '
                    'on the server.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Local data cleared')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<String?> _showZipCodeDialog() async {
    _zipCodeController.text = ref.read(zipCodeProvider);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set ZIP Code'),
        content: TextField(
          controller: _zipCodeController,
          keyboardType: TextInputType.number,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: 'ZIP Code',
            hintText: 'e.g., 92101',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final zipCode = _zipCodeController.text.trim();
              if (zipCode.isNotEmpty) {
                Navigator.pop(context, zipCode);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
