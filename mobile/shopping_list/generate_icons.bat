@echo off
REM Shopping Cart App Icon Generator Script for Windows
echo 🛒 Shopping Cart App Icon Generator
echo =====================================

REM Check if the icon file exists
if not exist "assets\shopping_cart_icon.png" (
    echo ❌ Error: assets\shopping_cart_icon.png not found!
    echo.
    echo Please create the shopping cart icon PNG file first:
    echo 1. Create a 1024x1024 PNG image with deep purple background
    echo 2. Add a white shopping cart icon
    echo 3. Save it as assets\shopping_cart_icon.png
    echo.
    echo You can use the app's Icon Generator page as a reference.
    pause
    exit /b 1
)

echo ✅ Icon file found: assets\shopping_cart_icon.png
echo.

REM Generate icons using flutter_launcher_icons
echo 🚀 Generating app icons...
flutter pub run flutter_launcher_icons:main

if %errorlevel% equ 0 (
    echo ✅ Icons generated successfully!
    echo.
    echo 🧹 Cleaning and rebuilding...
    flutter clean
    flutter pub get

    echo.
    echo 🎉 Icon generation complete!
    echo.
    echo Next steps:
    echo 1. Run: flutter run
    echo 2. The new shopping cart icon should now appear
    echo 3. Build release APK: flutter build apk --release
) else (
    echo ❌ Error generating icons!
    echo Please check the error messages above.
    pause
    exit /b 1
)

pause
