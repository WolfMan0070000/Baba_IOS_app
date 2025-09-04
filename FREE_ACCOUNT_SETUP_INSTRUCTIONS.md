# FREE Apple Developer Account Setup Instructions

## Before Running the Build Script

To successfully build the app with a FREE Apple Developer account, you need to complete these steps:

### 1. Sign in to Xcode with your Apple ID
1. Open Xcode
2. Go to **Xcode → Preferences → Accounts**
3. Click the **+** button and add your Apple ID
4. Sign in with your Apple ID credentials

### 2. Configure Project Signing
1. Open `Feather.xcworkspace` (not the .xcodeproj file)
2. Select the **Feather** project in the navigator
3. Select the **Feather** target
4. Go to **Signing & Capabilities** tab
5. Check **"Automatically manage signing"**
6. Select your **Team** from the dropdown (your personal team)
7. Xcode will automatically generate a provisioning profile

### 3. Verify Bundle Identifier
- Make sure the bundle identifier `BabaApp.Babaman.baba` is unique
- If you get conflicts, change it to something like `YourName.BabaApps.v1`

### 4. Test Build in Xcode First
Before running the script, try building in Xcode to ensure everything is set up correctly:
1. Select **Product → Archive** from the menu
2. If this works, the script should work too

## Running the Build Script

After completing the setup above:

```bash
cd /path/to/your/project
chmod +x build_ipa_free_account.sh
./build_ipa_free_account.sh
```

## Troubleshooting

### "Signing for Feather requires a development team"
- Make sure you've completed step 2 above
- Try building once in Xcode first to let it set up the team automatically

### "Failed to create provisioning profile"
- Your bundle identifier might not be unique
- Try changing the bundle identifier in the script and project settings

### Build succeeds but app won't install
- Use AltStore, Sideloadly, or similar tools for installation
- Free account apps expire after 7 days

## Free Account Limitations

With a free Apple Developer account:
- ✅ You can build and test apps
- ✅ You can install on your own devices
- ❌ Limited to 3 devices per year
- ❌ Apps expire after 7 days
- ❌ Some advanced entitlements are not available
- ❌ Cannot distribute through App Store

## Need Help?

If you continue to have issues:
1. Make sure your Apple ID is verified
2. Try cleaning the project (Product → Clean Build Folder)
3. Delete derived data (Xcode → Preferences → Locations → Derived Data → Delete)
4. Restart Xcode and try again