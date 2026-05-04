import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajustes',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Em breve.',
                style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            const Center(
              child: Icon(Icons.settings_outlined,
                  size: 64, color: AppTheme.textSecondary),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
