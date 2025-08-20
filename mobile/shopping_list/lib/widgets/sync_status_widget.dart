import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shopping_lists_service.dart';
import '../services/connection_manager.dart';
import '../l10n/app_localizations.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ShoppingListsService, ConnectionManager>(
      builder: (context, shoppingService, connectionManager, child) {
        final syncStatus = shoppingService.getSyncStatus();
        final detailedSyncStatus = shoppingService.getDetailedSyncStatus();
        final connectionStatus = connectionManager.getConnectionStatus();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Compact status row
                Row(
                  children: [
                                                      _buildStatusChip(
                                    icon: Icons.wifi,
                                    label: AppLocalizations.of(context)?.connection ?? 'Connection',
                                    status: connectionStatus['isConnected']
                                        ? (AppLocalizations.of(context)?.online ?? 'Online')
                                        : (AppLocalizations.of(context)?.offline ?? 'Offline'),
                                    color: connectionStatus['isConnected'] ? Colors.green : Colors.grey,
                                  ),
                    const SizedBox(width: 8),
                                                      _buildStatusChip(
                                    icon: Icons.cloud,
                                    label: AppLocalizations.of(context)?.webapp ?? 'Webapp',
                                    status: connectionStatus['isWebappAvailable']
                                        ? (AppLocalizations.of(context)?.available ?? 'Available')
                                        : (AppLocalizations.of(context)?.unavailable ?? 'Unavailable'),
                                    color: connectionStatus['isWebappAvailable'] ? Colors.blue : Colors.grey,
                                  ),
                    const SizedBox(width: 8),
                                                      _buildStatusChip(
                                    icon: Icons.sync,
                                    label: AppLocalizations.of(context)?.sync ?? 'Sync',
                                    status: syncStatus['listsNeedingSync'] > 0
                                        ? '${syncStatus['listsNeedingSync']} ${AppLocalizations.of(context)?.pending ?? 'pending'}'
                                        : AppLocalizations.of(context)?.upToDate ?? 'Up to date',
                                    color: syncStatus['listsNeedingSync'] > 0 ? Colors.orange : Colors.green,
                                  ),
                    const SizedBox(width: 8),
                                                      _buildStatusChip(
                                    icon: Icons.offline_pin,
                                    label: AppLocalizations.of(context)?.offline ?? 'Offline',
                                    status: detailedSyncStatus['offlineChanges'] > 0
                                        ? '${detailedSyncStatus['offlineChanges']} ${AppLocalizations.of(context)?.changes ?? 'changes'}'
                                        : AppLocalizations.of(context)?.noChanges ?? 'No changes',
                                    color: detailedSyncStatus['offlineChanges'] > 0 ? Colors.red : Colors.grey,
                                  ),
                  ],
                ),
                const SizedBox(height: 12),
                // Action buttons in a more compact layout
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: connectionStatus['canSync']
                            ? () => _importFromWebapp(context, shoppingService)
                            : null,
                        icon: const Icon(Icons.cloud_download, size: 18),
                                                              label: Text(AppLocalizations.of(context)?.import ?? 'Import', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: connectionStatus['canSync'] && syncStatus['listsNeedingSync'] > 0
                            ? () => _syncWithWebapp(context, shoppingService)
                            : null,
                        icon: const Icon(Icons.sync, size: 18),
                                                              label: Text(AppLocalizations.of(context)?.sync ?? 'Sync', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: connectionStatus['canSync']
                            ? () => _refreshFromWebapp(context, shoppingService)
                            : null,
                        icon: const Icon(Icons.refresh, size: 18),
                                                              label: Text(AppLocalizations.of(context)?.forceRefresh ?? 'Refresh', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                // Offline sync and force refresh buttons
                if (detailedSyncStatus['offlineChanges'] > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: connectionStatus['canSync']
                              ? () => _syncOfflineChanges(context, shoppingService)
                              : null,
                          icon: const Icon(Icons.upload, size: 18),
                                                                label: Text(AppLocalizations.of(context)?.syncOfflineChanges ?? 'Sync Offline Changes', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: connectionStatus['canSync']
                              ? () => _showForceRefreshDialog(context, shoppingService)
                              : null,
                          icon: const Icon(Icons.download, size: 18),
                                                                label: Text(AppLocalizations.of(context)?.forceRefresh ?? 'Force Refresh', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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

  void _refreshFromWebapp(BuildContext context, ShoppingListsService service) async {
    final result = await service.refreshFromWebapp();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _syncOfflineChanges(BuildContext context, ShoppingListsService service) async {
    final result = await service.syncOfflineChanges();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showForceRefreshDialog(BuildContext context, ShoppingListsService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.forceRefreshTitle ?? 'Force Refresh from Webapp'),
        content: Text(AppLocalizations.of(context)?.forceRefreshConfirm ??
          'This will download all data from the webapp and overwrite any local changes. '
          'This action cannot be undone. Are you sure you want to continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final result = await service.forceRefreshFromWebapp();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: result['success'] ? Colors.green : Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)?.forceRefresh ?? 'Force Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required String status,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 2),
            Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

