import 'package:flutter/material.dart';

class StatisticsCard extends StatelessWidget {
  final Map<String, int> statistics;

  const StatisticsCard({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shopping List Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatisticItem(
                    label: 'Total',
                    value: statistics['total'] ?? 0,
                    color: Theme.of(context).colorScheme.primary,
                    icon: Icons.shopping_cart,
                  ),
                ),
                Expanded(
                  child: _StatisticItem(
                    label: 'Pending',
                    value: statistics['pending'] ?? 0,
                    color: Colors.orange,
                    icon: Icons.pending,
                  ),
                ),
                Expanded(
                  child: _StatisticItem(
                    label: 'Completed',
                    value: statistics['completed'] ?? 0,
                    color: Colors.green,
                    icon: Icons.check_circle,
                  ),
                ),
              ],
            ),
            if (statistics['total'] != null && statistics['total']! > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: statistics['completed']! / statistics['total']!,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${((statistics['completed']! / statistics['total']!) * 100).toStringAsFixed(1)}% Complete',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
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
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
