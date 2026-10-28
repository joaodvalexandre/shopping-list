import 'package:flutter/material.dart';
import '../models/shopping_item.dart';
import '../l10n/app_localizations.dart';

class ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const ShoppingItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.onToggle,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      elevation: 2,
      child: ListTile(
        onTap: onTap,
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isPurchased ? TextDecoration.lineThrough : null,
            color: item.isPurchased ? Colors.grey : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${AppLocalizations.of(context)?.quantity ?? 'Quantity'}: ${item.quantity}',
                    style: TextStyle(
                      color: item.isPurchased ? Colors.grey : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(item).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(item)),
                  ),
                  child: Text(
                    _getStatusText(context, item),
                    style: TextStyle(
                      color: _getStatusColor(item),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Added: ${_formatDate(item.createdAt)}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status-specific action button
            if (onTap != null)
              IconButton(
                icon: Icon(_getActionIcon(item), size: 16),
                onPressed: onTap,
                tooltip: _getActionTooltip(context, item),
                style: IconButton.styleFrom(
                  backgroundColor: _getActionColor(item).withValues(alpha: 0.1),
                  foregroundColor: _getActionColor(item),
                  padding: const EdgeInsets.all(4),
                ),
              ),
            // Edit button (only for non-purchased items)
            if (onEdit != null && !item.isPurchased)
              IconButton(
                icon: const Icon(Icons.edit, size: 16),
                onPressed: onEdit,
                tooltip: AppLocalizations.of(context)?.editItem ?? 'Edit item',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.all(4),
                ),
              ),
            // Delete button
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete, size: 16),
                onPressed: onDelete,
                tooltip: AppLocalizations.of(context)?.deleteItem ?? 'Delete item',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.all(4),
                ),
              ),
          ],
        ),
        isThreeLine: false,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getStatusColor(ShoppingItem item) {
    switch (item.status) {
      case ItemStatus.toBuy:
        return Colors.orange;
      case ItemStatus.inCart:
        return Colors.blue;
      case ItemStatus.purchased:
        return Colors.green;
    }
  }

  String _getStatusText(BuildContext context, ShoppingItem item) {
    switch (item.status) {
      case ItemStatus.toBuy:
        return AppLocalizations.of(context)?.toBuy ?? 'To Buy';
      case ItemStatus.inCart:
        return AppLocalizations.of(context)?.inCart ?? 'In Cart';
      case ItemStatus.purchased:
        return AppLocalizations.of(context)?.purchased ?? 'Purchased';
    }
  }

  IconData _getActionIcon(ShoppingItem item) {
    switch (item.status) {
      case ItemStatus.toBuy:
        return Icons.add_shopping_cart; // Add to cart
      case ItemStatus.inCart:
        return Icons.remove_shopping_cart; // Remove from cart
      case ItemStatus.purchased:
        return Icons.check_circle; // Already purchased
    }
  }

  Color _getActionColor(ShoppingItem item) {
    switch (item.status) {
      case ItemStatus.toBuy:
        return Colors.blue;
      case ItemStatus.inCart:
        return Colors.orange;
      case ItemStatus.purchased:
        return Colors.grey;
    }
  }

  String _getActionTooltip(BuildContext context, ShoppingItem item) {
    switch (item.status) {
      case ItemStatus.toBuy:
        return AppLocalizations.of(context)?.addToCart ?? 'Add to cart';
      case ItemStatus.inCart:
        return AppLocalizations.of(context)?.removeFromCart ?? 'Remove from cart';
      case ItemStatus.purchased:
        return 'Already purchased';
    }
  }
}
