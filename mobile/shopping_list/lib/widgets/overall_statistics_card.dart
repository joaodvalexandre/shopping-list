import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class OverallStatisticsCard extends StatelessWidget {
  final Map<String, int> statistics;

  const OverallStatisticsCard({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.shoppingLists ?? 'Overview',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatisticItem(
                    label: AppLocalizations.of(context)?.totalLists ?? 'Lists',
                    value: statistics['totalLists'] ?? 0,
                    color: Theme.of(context).colorScheme.primary,
                    icon: Icons.list_alt,
                  ),
                ),
                Expanded(
                  child: _StatisticItem(
                    label: 'Active',
                    value: statistics['activeLists'] ?? 0,
                    color: Colors.blue,
                    icon: Icons.play_circle,
                  ),
                ),
                Expanded(
                  child: _StatisticItem(
                    label: 'Completed',
                    value: statistics['completedLists'] ?? 0,
                    color: Colors.green,
                    icon: Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _StatisticItem(
                    label: AppLocalizations.of(context)?.totalItems ?? 'Items',
                    value: statistics['totalItems'] ?? 0,
                    color: Colors.orange,
                    icon: Icons.shopping_cart,
                  ),
                ),
              ],
            ),
            if (statistics['totalItems'] != null && statistics['totalItems']! > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: statistics['completedItems']! / statistics['totalItems']!,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${((statistics['completedItems']! / statistics['totalItems']!) * 100).toStringAsFixed(1)}% completed',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatisticItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatisticItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
