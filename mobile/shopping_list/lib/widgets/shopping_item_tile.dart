import 'package:flutter/material.dart';
import '../models/shopping_item.dart';

class ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      elevation: 2,
      child: ListTile(
        leading: Checkbox(
          value: item.isCompleted,
          onChanged: (_) => onToggle(),
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
            color: item.isCompleted ? Colors.grey : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quantity: ${item.quantity}',
              style: TextStyle(
                color: item.isCompleted ? Colors.grey : null,
              ),
            ),
            if (item.category != null)
              Text(
                'Category: ${item.category}',
                style: TextStyle(
                  color: item.isCompleted ? Colors.grey : Colors.blue[700],
                  fontSize: 12,
                ),
              ),
            if (item.notes != null)
              Text(
                'Notes: ${item.notes}',
                style: TextStyle(
                  color: item.isCompleted ? Colors.grey : Colors.orange[700],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
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
            IconButton(
              icon: Icon(
                Icons.edit,
                color: item.isCompleted ? Colors.grey : Colors.blue,
              ),
              onPressed: item.isCompleted ? null : onEdit,
              tooltip: 'Edit item',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete item',
            ),
          ],
        ),
        isThreeLine: true,
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
}
