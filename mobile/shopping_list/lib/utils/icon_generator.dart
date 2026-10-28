import 'package:flutter/material.dart';

/// Simple shopping cart icon generator
class IconGenerator {
  /// Creates a basic shopping cart icon
  static Widget createBasicIcon({
    double size = 1024,
    Color color = Colors.deepPurple,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: size * 0.1,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: Icon(
        Icons.shopping_cart,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }

  /// Creates a shopping cart icon with items indicator
  static Widget createIconWithItems({
    double size = 1024,
    Color color = Colors.deepPurple,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: size * 0.15,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main shopping cart icon
          Icon(
            Icons.shopping_cart,
            color: Colors.white,
            size: size * 0.5,
          ),
          // Items indicator
          Positioned(
            top: size * 0.2,
            right: size * 0.2,
            child: Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: size * 0.02),
              ),
              child: Center(
                child: Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
