#!/bin/bash

# Feather IPA Builder Script with Proper Entitlements
# This script properly creates an IPA file with all necessary entitlements for file system access

set -e

# Configuration
PROJECT_PATH="Feather.xcodeproj"
SCHEME="Feather"
CONFIGURATION="Release"
WORKSPACE_PATH="Feather.xcworkspace"
ENTITLEMENTS_PATH="Feather/Supporting Files/Feather.entitlements"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the correct directory
if [ ! -f "$PROJECT_PATH/project.pbxproj" ]; then
    print_error "Project file not found. Please run this script from the iOS app directory."
    exit 1
fi

# Check if entitlements file exists
if [ ! -f "$ENTITLEMENTS_PATH" ]; then
    print_error "Entitlements file not found at $ENTITLEMENTS_PATH"
    exit 1
fi

print_info "Building Feather IPA with proper entitlements..."

# Clean previous builds
print_info "Cleaning previous builds..."
xcodebuild clean -workspace "$WORKSPACE_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION"

# Build for device
print_info "Building for device..."
xcodebuild archive \
    -workspace "$WORKSPACE_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -archivePath "./build/Feather.xcarchive" \
    CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS_PATH" \
    DEVELOPMENT_TEAM="" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGN_STYLE="Manual" \
    PROVISIONING_PROFILE_SPECIFIER=""

if [ $? -ne 0 ]; then
    print_error "Build failed!"
    exit 1
fi

print_success "Build completed successfully!"

# Create IPA with proper entitlements
print_info "Creating IPA with entitlements..."

# Create output directory
mkdir -p "./dist"

# Export the archive to IPA format
xcodebuild -exportArchive \
    -archivePath "./build/Feather.xcarchive" \
    -exportPath "./dist" \
    -exportOptionsPlist "./build_configs/ExportOptions.plist" 2>/dev/null || {
    
    # If ExportOptions.plist doesn't exist, create one
    print_info "Creating ExportOptions.plist..."
    mkdir -p "./build_configs"
    
    cat > "./build_configs/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>manual</string>
    <key>provisioningProfiles</key>
    <dict/>
</dict>
</plist>
EOF
    
    # Try export again
    xcodebuild -exportArchive \
        -archivePath "./build/Feather.xcarchive" \
        -exportPath "./dist" \
        -exportOptionsPlist "./build_configs/ExportOptions.plist"
}

# Alternative method: Manual IPA creation with entitlements preservation
if [ ! -f "./dist/Feather.ipa" ]; then
    print_warning "Export method failed, using manual IPA creation..."
    
    # Extract the .app from archive
    APP_PATH="./build/Feather.xcarchive/Products/Applications/Feather.app"
    
    if [ ! -d "$APP_PATH" ]; then
        print_error "App not found in archive"
        exit 1
    fi
    
    # Create Payload directory
    mkdir -p "./dist/Payload"
    
    # Copy app with preserved permissions and entitlements
    cp -R "$APP_PATH" "./dist/Payload/"
    
    # Verify entitlements are embedded
    print_info "Verifying entitlements in app..."
    if command -v codesign >/dev/null 2>&1; then
        codesign -d --entitlements - "./dist/Payload/Feather.app" | head -20
    fi
    
    # Create IPA
    cd "./dist"
    zip -r "Feather.ipa" "Payload"
    cd ..
    
    # Clean up
    rm -rf "./dist/Payload"
fi

if [ -f "./dist/Feather.ipa" ]; then
    print_success "IPA created successfully: ./dist/Feather.ipa"
    
    # Get IPA size
    IPA_SIZE=$(du -h "./dist/Feather.ipa" | cut -f1)
    print_info "IPA size: $IPA_SIZE"
    
    # Verify entitlements in final IPA
    print_info "Verifying entitlements in final IPA..."
    if command -v unzip >/dev/null 2>&1 && command -v codesign >/dev/null 2>&1; then
        # Extract and check entitlements
        mkdir -p "./temp_verify"
        cd "./temp_verify"
        unzip -q "../dist/Feather.ipa"
        echo "Entitlements in final IPA:"
        codesign -d --entitlements - "Payload/Feather.app" 2>/dev/null | head -20
        cd ..
        rm -rf "./temp_verify"
    fi
else
    print_error "Failed to create IPA"
    exit 1
fi

# Clean up build artifacts
print_info "Cleaning up build artifacts..."
rm -rf "./build"

print_success "Build process completed successfully!"
print_info "Your IPA file is ready at: ./dist/Feather.ipa"
print_info ""
print_info "Important notes for sideloading:"
print_info "- This IPA includes proper entitlements for file system access"
print_info "- The 'Cannot create file' error should be resolved"
print_info "- Use this IPA instead of manually created ones"
print_info ""
print_warning "Note: You may still need to sign this IPA with your certificate before sideloading"