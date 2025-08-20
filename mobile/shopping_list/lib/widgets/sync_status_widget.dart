import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shopping_lists_service.dart';
import '../services/connection_manager.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ShoppingListsService, ConnectionManager>(
      builder: (context, shoppingService, connectionManager, child) {
        final syncStatus = shoppingService.getSyncStatus();
        final connectionStatus = connectionManager.getConnectionStatus();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      connectionStatus['isConnected']
                          ? Icons.wifi
                          : Icons.wifi_off,
                      color: connectionStatus['isConnected']
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Connection Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    _buildConnectionIndicator(connectionStatus),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      connectionStatus['isWebappAvailable']
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                      color: connectionStatus['isWebappAvailable']
                          ? Colors.blue
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Webapp Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    _buildWebappIndicator(connectionStatus),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.sync,
                      color: syncStatus['listsNeedingSync'] > 0
                          ? Colors.orange
                          : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sync Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    _buildSyncIndicator(syncStatus),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: connectionStatus['canSync']
                            ? () => _importFromWebapp(context, shoppingService)
                            : null,
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Import'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: connectionStatus['canSync'] && syncStatus['listsNeedingSync'] > 0
                            ? () => _syncWithWebapp(context, shoppingService)
                            : null,
                        icon: const Icon(Icons.sync),
                        label: const Text('Sync'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionIndicator(Map<String, dynamic> status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status['isConnected'] ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status['isConnected'] ? 'Online' : 'Offline',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildWebappIndicator(Map<String, dynamic> status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status['isWebappAvailable'] ? Colors.blue : Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status['isWebappAvailable'] ? 'Available' : 'Unavailable',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSyncIndicator(Map<String, dynamic> status) {
    final needsSync = status['listsNeedingSync'] > 0;
    final color = needsSync ? Colors.orange : Colors.green;
    final text = needsSync
        ? '${status['listsNeedingSync']} pending'
        : 'Up to date';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _importFromWebapp(BuildContext context, ShoppingListsService service) async {
    final result = await service.importFromWebapp();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _syncWithWebapp(BuildContext context, ShoppingListsService service) async {
    final result = await service.syncWithWebapp();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
