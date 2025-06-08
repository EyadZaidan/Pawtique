import 'package:shared_preferences/shared_preferences.dart';

class LocalFavoritesManager {
  static const _favoritesKey = 'favorite_product_ids';

  static Future<List<String>> getFavoriteIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_favoritesKey) ?? [];
    } catch (e) {
      print('Error getting favorite IDs: $e');
      return [];
    }
  }

  static Future<bool> isFavorite(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(_favoritesKey) ?? [];
      return current.contains(productId);
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  static Future<void> addFavorite(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(_favoritesKey) ?? [];
      if (!current.contains(productId)) {
        current.add(productId);
        await prefs.setStringList(_favoritesKey, current);
      }
    } catch (e) {
      print('Error adding favorite: $e');
      throw Exception('Failed to add favorite: $e');
    }
  }

  static Future<void> removeFavorite(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(_favoritesKey) ?? [];
      current.remove(productId);
      await prefs.setStringList(_favoritesKey, current);
    } catch (e) {
      print('Error removing favorite: $e');
      throw Exception('Failed to remove favorite: $e');
    }
  }

  static Future<void> toggleFavorite(String productId) async {
    try {
      final isFav = await isFavorite(productId);
      if (isFav) {
        await removeFavorite(productId);
      } else {
        await addFavorite(productId);
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      throw Exception('Failed to toggle favorite: $e');
    }
  }
}