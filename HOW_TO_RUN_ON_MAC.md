# 🍎 How to Run .sh Script on Mac - BabaApps Build Guide

## 📱 App Name Changed
✅ **App name has been changed from "Feather" to "BabaApps"**
- Display name in iOS: **BabaApps**
- IPA file output: **BabaApps-FreeBuild.ipa**

## 🚀 Running the Build Script on Mac

### Step 1: Open Terminal
Press `⌘ + Space` and type "Terminal" then press Enter

### Step 2: Navigate to Project Directory
```bash
cd "/path/to/Baba App IOS app"
```

**Example:**
```bash
cd "/Users/erfan/Documents/55/Baba App IOS app"
```

### Step 3: Make Script Executable
```bash
chmod +x build_ipa_free_account.sh
```

### Step 4: Run the Script
```bash
./build_ipa_free_account.sh
```

## 🔧 Alternative Methods

### Method 1: One-Line Command
```bash
cd "/Users/erfan/Documents/55/Baba App IOS app" && chmod +x build_ipa_free_account.sh && ./build_ipa_free_account.sh
```

### Method 2: Using Bash Directly
```bash
bash build_ipa_free_account.sh
```

### Method 3: Drag & Drop Method
1. Open Terminal
2. Type: `chmod +x ` (with space at the end)
3. Drag the `build_ipa_free_account.sh` file into Terminal
4. Press Enter
5. Type: `./` 
6. Drag the script file again
7. Press Enter

## 📋 Complete Step-by-Step Guide

### 1. Preparation
```bash
# Check if you're in the right directory
pwd
ls -la | grep "Feather.xcodeproj"
```

### 2. Make Script Executable
```bash
chmod +x build_ipa_free_account.sh
```

### 3. Verify Script Permissions
```bash
ls -la build_ipa_free_account.sh
```
You should see: `-rwxr-xr-x` (the `x` means executable)

### 4. Run the Build
```bash
./build_ipa_free_account.sh
```

## 🎯 Expected Output

```
[INFO] 🆓 Building BabaApps IPA for FREE Apple Developer Account
[WARNING] ⚠️  Note: Some advanced features may be limited due to free account restrictions
[INFO] Building with simplified entitlements for free account...
[INFO] Cleaning previous builds...
[INFO] Building for device with automatic signing...
[SUCCESS] Build completed successfully!
[INFO] Creating IPA...
[SUCCESS] IPA created successfully: ./dist/BabaApps-FreeBuild.ipa
[SUCCESS] 🎉 Build process completed successfully!
[INFO] Your IPA file is ready at: ./dist/BabaApps-FreeBuild.ipa
```

## 📂 Output Location

Your IPA file will be created at:
```
./dist/BabaApps-FreeBuild.ipa
```

## ⚠️ Common Issues & Solutions

### Issue 1: Permission Denied
```bash
# Error: permission denied
# Solution:
chmod +x build_ipa_free_account.sh
```

### Issue 2: Command Not Found
```bash
# Error: ./build_ipa_free_account.sh: command not found
# Solution: Make sure you're in the right directory
pwd
ls -la | grep build_ipa_free_account.sh
```

### Issue 3: Xcode Not Found
```bash
# Error: xcodebuild: command not found
# Solution: Install Xcode Command Line Tools
xcode-select --install
```

### Issue 4: Developer Account Issues
```bash
# Error: No signing certificate found
# Solution: Open Xcode and sign in to your Apple ID
# Xcode → Preferences → Accounts → Add Apple ID
```

## 🔍 Verification Commands

### Check if IPA was created:
```bash
ls -la ./dist/
file ./dist/BabaApps-FreeBuild.ipa
```

### Check IPA size:
```bash
du -h ./dist/BabaApps-FreeBuild.ipa
```

### Verify app signing (if codesign available):
```bash
unzip -q ./dist/BabaApps-FreeBuild.ipa -d temp_check
codesign -vv -d temp_check/Payload/Feather.app
rm -rf temp_check
```

## 📱 Installation Instructions

After the IPA is created, you can install it using:

### Option 1: AltStore
1. Install AltStore on your Mac and iPhone
2. Use AltStore to install the IPA file

### Option 2: Sideloadly 
1. Download Sideloadly
2. Connect your iPhone
3. Drag the IPA file to Sideloadly

### Option 3: Xcode (Direct Installation)
```bash
# Install directly via Xcode (if device is connected)
xcrun devicectl device install app --device [DEVICE_ID] ./dist/BabaApps-FreeBuild.ipa
```

## 🎉 Success!

If everything works correctly, you should have:
- ✅ **BabaApps.ipa** file created
- ✅ App name shows as "BabaApps" on iPhone
- ✅ File download functionality working
- ✅ No "Cannot create file" errors

## 🆘 Need Help?

If you encounter issues:
1. Make sure Xcode is installed and updated
2. Sign in to your Apple Developer account in Xcode
3. Check that your bundle ID matches: `BabaApp.Babaman.baba`
4. Ensure you're using a FREE Apple Developer account compatible entitlements

---

**Note**: The script is optimized for FREE Apple Developer accounts. Some advanced features may be limited compared to paid accounts ($99/year).