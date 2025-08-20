# Shopping List Mobile App

A Flutter mobile application for managing shopping lists with web synchronization capabilities.

## Features

- **Local Storage**: Store shopping lists locally using SharedPreferences
- **Web Synchronization**: Sync with Laravel webapp when connected
- **Offline Support**: Full functionality without internet connection
- **Real-time Status**: Connection and sync status indicators
- **Import/Export**: Import lists from webapp and sync local changes

## Web Synchronization

The app automatically detects when it's connected to the internet and when the Laravel webapp is available. It provides:

- **Connection Status**: Shows internet connectivity
- **Webapp Status**: Shows if the webapp is reachable
- **Sync Status**: Shows how many lists need synchronization
- **Import Button**: Download lists from the webapp
- **Sync Button**: Upload local changes to the webapp

## API Configuration

The app is configured to connect to the Laravel webapp at:

- **Current Configuration**: `http://raspfofs/api`
- **Customization**: Update the URL in `web_api_service.dart` if needed

## API Endpoints

The Laravel webapp provides these endpoints:

- `GET /api/shopping-lists/health` - Health check
- `GET /api/shopping-lists` - Fetch all lists
- `POST /api/shopping-lists` - Create new list
- `PUT /api/shopping-lists/{id}` - Update list
- `DELETE /api/shopping-lists/{id}` - Delete list
- `POST /api/shopping-lists/sync` - Sync multiple lists

## Data Flow

1. **Local Creation**: Lists are created locally first
2. **Auto-sync**: If webapp is available, lists are automatically synced
3. **Conflict Resolution**: Local changes take precedence during sync
4. **Bidirectional Sync**: Changes flow both ways between mobile and web

## Offline Mode

When offline:
- All functionality works locally
- Changes are queued for sync when connection is restored
- No data loss occurs

## Getting Started

1. Ensure the Laravel webapp is running at `http://raspfofs/dashboard`
2. The API endpoints should be accessible at `http://raspfofs/dashboard/api/*`
3. Run the Flutter app
4. The app will automatically detect the webapp connection
5. Use the sync buttons to import/export data

## Dependencies

- `http`: For API communication
- `connectivity_plus`: For network status detection
- `shared_preferences`: For local storage
- `provider`: For state management
