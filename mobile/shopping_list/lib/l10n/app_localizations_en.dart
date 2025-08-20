// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Smart Shopping';

  @override
  String get shoppingLists => 'Shopping Lists';

  @override
  String get createNewList => 'Create New List';

  @override
  String get listName => 'List Name';

  @override
  String get listNameRequired => 'Please enter a list name';

  @override
  String get listNameHint => 'e.g., Groceries, Home Supplies, Party Shopping';

  @override
  String get create => 'Create';

  @override
  String get update => 'Update';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get addItem => 'Add Item';

  @override
  String get editItem => 'Edit Item';

  @override
  String get itemName => 'Item Name';

  @override
  String get itemNameRequired => 'Please enter an item name';

  @override
  String get itemNameHint => 'e.g., Milk, Bread, Apples';

  @override
  String get quantity => 'Quantity';

  @override
  String get quantityHint => '1';

  @override
  String get add => 'Add';

  @override
  String get deleteList => 'Delete Shopping List';

  @override
  String get deleteListConfirm => 'Are you sure you want to delete this shopping list? This action cannot be undone.';

  @override
  String get deleteItem => 'Delete Item';

  @override
  String deleteItemConfirm(Object itemName) {
    return 'Are you sure you want to delete \"$itemName\"?';
  }

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get removeFromCart => 'Remove from Cart';

  @override
  String get markAllAsPurchased => 'Mark All as Purchased';

  @override
  String get markAllAsPurchasedConfirm => 'Mark all items in cart as purchased?';

  @override
  String get connection => 'Connection';

  @override
  String get webapp => 'Webapp';

  @override
  String get sync => 'Sync';

  @override
  String get offline => 'Offline';

  @override
  String get online => 'Online';

  @override
  String get available => 'Available';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get pending => 'pending';

  @override
  String get upToDate => 'Up to date';

  @override
  String get changes => 'changes';

  @override
  String get noChanges => 'No changes';

  @override
  String get import => 'Import';

  @override
  String get syncOfflineChanges => 'Sync Offline Changes';

  @override
  String get forceRefresh => 'Force Refresh';

  @override
  String get forceRefreshConfirm => 'This will download all data from the webapp and overwrite any local changes. This action cannot be undone. Are you sure you want to continue?';

  @override
  String get forceRefreshTitle => 'Force Refresh from Webapp';

  @override
  String get noShoppingLists => 'No shopping lists found';

  @override
  String get noShoppingListsHint => 'Create your first shopping list to get started!';

  @override
  String get checkWebappConnection => 'Check webapp connection';

  @override
  String get toBuy => 'To Buy';

  @override
  String get inCart => 'In Cart';

  @override
  String get purchased => 'Purchased';

  @override
  String get totalLists => 'Total Lists';

  @override
  String get totalItems => 'Total Items';

  @override
  String get itemsInCart => 'Items in Cart';

  @override
  String get itemsPurchased => 'Items Purchased';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get portuguese => 'Portuguese';

  @override
  String get changeLanguage => 'Change Language';

  @override
  String get editList => 'Edit List';
}
