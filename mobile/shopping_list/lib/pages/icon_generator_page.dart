import 'package:flutter/material.dart';
import '../utils/icon_generator.dart';

class IconGeneratorPage extends StatelessWidget {
  const IconGeneratorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Icon Generator'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Shopping Cart Icon Options',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // Option 1: Detailed icon
            const Text(
              'Option 1: Detailed Icon (with item count)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconGenerator.createIconWithItems(
                size: 150,
                color: Colors.deepPurple,
              ),
            ),

            const SizedBox(height: 32),

            // Option 2: Simple icon
            const Text(
              'Option 2: Simple Icon (clean design)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconGenerator.createBasicIcon(
                size: 150,
                color: Colors.deepPurple,
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              'Choose your preferred icon style for the app',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Detailed icon selected!'),
                      ),
                    );
                  },
                  child: const Text('Use Detailed'),
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Simple icon selected!'),
                      ),
                    );
                  },
                  child: const Text('Use Simple'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
