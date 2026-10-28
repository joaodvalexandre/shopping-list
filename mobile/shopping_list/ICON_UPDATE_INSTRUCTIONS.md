# App Icon Update Instructions

## 🛒 Changing App Icon to Shopping Cart

The app icon has been updated to use a shopping cart design. Here are the steps to apply the new icon:

### **Option 1: Use Flutter's Icon Generator (Recommended)**

1. **Install flutter_launcher_icons package:**
   ```bash
   flutter pub add --dev flutter_launcher_icons
   ```

2. **Create icon configuration in pubspec.yaml:**
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.14.4

   flutter_launcher_icons:
     android: "launcher_icon"
     ios: true
     image_path: "assets/shopping_cart_icon.png"
     min_sdk_android: 21
     web:
       generate: true
       image_path: "assets/shopping_cart_icon.png"
       background_color: "#7C3AED"
       theme_color: "#7C3AED"
   ```

3. **Generate icons:**
   ```bash
   flutter pub get
   dart run flutter_launcher_icons
   ```

### **Option 2: Manual Icon Replacement**

#### **Android Icons:**
Replace the following files with shopping cart icons:

- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` (72x72)
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` (48x48)
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` (96x96)
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (144x144)
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (192x192)

#### **iOS Icons:**
Replace the following files with shopping cart icons:

- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png` (20x20)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png` (40x40)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png` (60x60)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png` (29x29)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png` (58x58)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png` (87x87)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png` (40x40)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png` (80x80)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png` (120x120)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png` (120x120)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png` (180x180)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png` (76x76)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png` (152x152)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png` (167x167)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` (1024x1024)

### **Icon Design Specifications:**

- **Primary Color:** Deep Purple (#7C3AED)
- **Secondary Color:** Dark Purple (#4C1D95)
- **Accent Color:** Orange (#F59E0B) for item count
- **Background:** Gradient from primary to secondary
- **Shape:** Rounded rectangle with shopping cart icon
- **Style:** Modern, clean, and recognizable

### **Quick Test:**

To see the new icon design in the app:

1. Navigate to the Icon Generator page in the app
2. The preview shows exactly how the new icon will look
3. Use this as a reference when creating the actual icon files

### **After Icon Update:**

1. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Test on device:**
   ```bash
   flutter run
   ```

3. **Build release APK:**
   ```bash
   flutter build apk --release
   ```

The new shopping cart icon will make the app more recognizable and clearly indicate its purpose as a shopping list application! 🛒✨
