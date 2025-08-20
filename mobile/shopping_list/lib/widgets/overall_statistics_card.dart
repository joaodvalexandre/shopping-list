import 'package:flutter/material.dart';

class OverallStatisticsCard extends StatelessWidget {
  final Map<String, int> statistics;

  const OverallStatisticsCard({
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
              'Shopping Lists Overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatisticItem(
                    label: 'Lists',
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
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatisticItem(
                    label: 'Total Items',
                    value: statistics['totalItems'] ?? 0,
                    color: Colors.orange,
                    icon: Icons.shopping_cart,
                  ),
                ),
                Expanded(
                  child: _StatisticItem(
                    label: 'Pending',
                    value: statistics['pendingItems'] ?? 0,
                    color: Colors.red,
                    icon: Icons.pending,
                  ),
                ),
                Expanded(
                  child: _StatisticItem(
                    label: 'Done',
                    value: statistics['completedItems'] ?? 0,
                    color: Colors.green,
                    icon: Icons.done_all,
                  ),
                ),
              ],
            ),
            if (statistics['totalItems'] != null && statistics['totalItems']! > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: statistics['completedItems']! / statistics['totalItems']!,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${((statistics['completedItems']! / statistics['totalItems']!) * 100).toStringAsFixed(1)}% of all items completed',
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
          size: 28,
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
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
