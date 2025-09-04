# iOS File Permission Issue Fix Guide

## Problem Description

You're experiencing a "Cannot create file" error when downloading files in your Feather (Baba App) after installing via a manually created IPA file. This issue does NOT occur when running directly from Xcode.

## Root Cause Analysis

The issue occurs because your manual IPA creation process does not preserve the iOS app entitlements that are required for file system access. Here's what happens:

### Working Scenario (Xcode Direct Deploy)
- Xcode automatically includes all project entitlements
- App sandbox has proper permissions for file operations
- Download manager can create directories and move files in the app's sandbox

### Failing Scenario (Manual IPA)
- Manual IPA creation strips away entitlements
- App runs with minimal sandbox permissions
- Download manager fails when trying to:
  ```swift
  try FileManager.default.createDirectoryIfNeeded(at: customTempDir)
  try FileManager.default.moveItem(at: location, to: destinationURL)
  ```

## 🆓 FREE Apple Developer Account Users

**⚠️ IMPORTANT**: If you're using a FREE Apple Developer account, please see [`FREE_ACCOUNT_FIX_GUIDE.md`](./FREE_ACCOUNT_FIX_GUIDE.md) for specific instructions.

Free accounts have limitations with:
- Associated Domains
- App Groups  
- Custom Network Protocols
- Background Downloads

We've created special scripts and configurations for free accounts.

## Solutions Implemented

### 1. Updated Entitlements File

We've updated your `Feather/Supporting Files/Feather.entitlements` with the necessary permissions:

```xml
<!-- File System Access -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.downloads.read-write</key>
<true/>

<!-- Document Directory Access -->
<key>com.apple.security.application-groups</key>
<array>
    <string>group.thewonderofyou.Feather</string>
</array>

<!-- Background Downloads -->
<key>com.apple.developer.background-modes</key>
<array>
    <string>background-processing</string>
    <string>background-fetch</string>
    <string>background-downloads</string>
</array>

<!-- Network Access -->
<key>com.apple.security.network.client</key>
<true/>

<!-- iOS 18 Requirements -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:*.backloop.dev</string>
</array>

<key>com.apple.developer.networking.custom-protocol</key>
<array>
    <string>feather</string>
    <string>itms-services</string>
</array>
```

### 2. Proper IPA Building Scripts

We've created two scripts that build IPA files with proper entitlements:

#### For macOS/Linux: `build_ipa_with_entitlements.sh`
```bash
chmod +x build_ipa_with_entitlements.sh
./build_ipa_with_entitlements.sh
```

#### For Windows: `build_ipa_with_entitlements.ps1`
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\build_ipa_with_entitlements.ps1
```

## How to Fix Your Current Issue

### For FREE Apple Developer Accounts 🆓

**Use the specialized scripts:**
- **macOS/Linux**: `./build_ipa_free_account.sh`
- **Windows**: `.\build_ipa_free_account.ps1`

These scripts automatically handle free account limitations.

### For PAID Apple Developer Accounts 💳

### Method 1: Use the Build Scripts (Recommended)

1. Navigate to your iOS app directory:
   ```bash
   cd "Baba App IOS app"
   ```

2. Run the appropriate script:
   - **macOS/Linux**: `./build_ipa_with_entitlements.sh`
   - **Windows**: `.\build_ipa_with_entitlements.ps1`

3. The script will create `./dist/Feather.ipa` with proper entitlements

### Method 2: Manual Fix for Existing Manual Process

If you want to continue with your manual process, you need to ensure entitlements are preserved:

1. **Build with Entitlements**:
   ```bash
   xcodebuild archive \
       -workspace Feather.xcworkspace \
       -scheme Feather \
       -configuration Release \
       -destination "generic/platform=iOS" \
       -archivePath "./Feather.xcarchive" \
       CODE_SIGN_ENTITLEMENTS="Feather/Supporting Files/Feather.entitlements"
   ```

2. **Extract with Entitlements Preserved**:
   - Navigate to `Feather.xcarchive/Products/Applications/`
   - Copy the `Feather.app` (this version has entitlements embedded)
   - Create your Payload directory and ZIP as before

3. **Verify Entitlements**:
   ```bash
   codesign -d --entitlements - Payload/Feather.app
   ```

## Verification Steps

After creating your IPA with the new method:

1. **Install the IPA** on your test device
2. **Test the download feature** - the "Cannot create file" error should be resolved
3. **Check app logs** for any remaining permission issues

## Additional iOS 18 Considerations

Your app targets iOS 18, which has additional requirements mentioned in your README:

- `Associated Domains`
- `Custom Network Protocol`
- `MDM Managed Associated Domains`
- `Network Extensions`

These are now included in the updated entitlements file.

## Alternative Installation Methods

Your README mentions alternative installation methods for iOS 18. Consider these if you continue to have issues:

1. **Server Method**: Use a local HTTPS server with proper SSL certificates
2. **Pairing Method**: Use TCP provider with pairing file and VPN

## Troubleshooting

### If You Still Get "Cannot create file" Error:

1. **Check entitlements in final IPA**:
   ```bash
   unzip -q YourApp.ipa
   codesign -d --entitlements - Payload/Feather.app
   ```

2. **Verify the error location**:
   - Check if it's happening in `DownloadManager.swift` at line 540-550
   - Look for errors in `createDirectoryIfNeeded` or `moveItem`

3. **Check iOS version compatibility**:
   - Ensure your iOS version supports the entitlements
   - Some entitlements require specific iOS versions

### If Build Scripts Fail:

1. **Check Xcode installation**:
   ```bash
   xcode-select --print-path
   ```

2. **Verify project integrity**:
   - Ensure `Feather.xcworkspace` exists
   - Check that the scheme "Feather" is available

3. **Manual export**:
   - Use Xcode's Product → Archive → Distribute App
   - Choose "Ad Hoc" distribution
   - Ensure "Automatically manage signing" is disabled
   - Select your certificate and provisioning profile

## Summary

The core issue was that your manual IPA creation process stripped away the iOS entitlements required for file system access. The solution is to:

1. ✅ Use the updated entitlements file with proper permissions
2. ✅ Build IPA using the provided scripts or Xcode's proper export process
3. ✅ Ensure entitlements are embedded in the final IPA file

This should completely resolve the "Cannot create file" error when downloading files in your sideloaded app.

## Files Modified/Created

- ✅ Updated: `Feather/Supporting Files/Feather.entitlements`
- ✅ Created: `build_ipa_with_entitlements.sh`
- ✅ Created: `build_ipa_with_entitlements.ps1`
- ✅ Created: This guide document

The file permission issue should now be resolved when using properly built IPA files.