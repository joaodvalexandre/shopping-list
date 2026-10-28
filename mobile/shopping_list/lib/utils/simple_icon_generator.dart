import 'package:flutter/material.dart';

/// Simple icon generator using Flutter's built-in icons
class SimpleIconGenerator {
  /// Creates a shopping cart icon using Flutter's built-in icon
  static Widget createShoppingCartIcon({
    double size = 1024,
    Color color = Colors.deepPurple,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
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

  /// Creates a more detailed shopping cart icon
  static Widget createDetailedShoppingCartIcon({
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
            color.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
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
          // Small items indicator
          Positioned(
            top: size * 0.25,
            right: size * 0.25,
            child: Container(
              width: size * 0.15,
              height: size * 0.15,
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
                    fontSize: size * 0.08,
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
