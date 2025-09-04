#!/bin/bash

# BabaApps IPA Builder for FREE Apple Developer Accounts
# این اسکریپت برای اکانت‌های رایگان طراحی شده است

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

# Welcome message for free account users
print_info "🆓 Building BabaApps IPA for FREE Apple Developer Account"
print_warning "⚠️  Note: Some advanced features may be limited due to free account restrictions"
print_info "📋 Before running this script, make sure you have:"
print_info "   1. Signed in to Xcode with your Apple ID (Xcode → Preferences → Accounts)"
print_info "   2. Opened the project in Xcode and resolved any signing issues"
print_info "   3. Selected 'Automatically manage signing' in project settings"
print_info "   4. Verified that your bundle identifier is unique"
print_info ""

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

print_info "Building with simplified entitlements for free account..."

# Clean previous builds
print_info "Cleaning previous builds..."
xcodebuild clean -workspace "$WORKSPACE_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION"

# Build for device with automatic signing
print_info "Building for device with automatic signing..."
xcodebuild archive \
    -workspace "$WORKSPACE_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -archivePath "./build/Feather.xcarchive" \
    CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS_PATH" \
    CODE_SIGN_STYLE="Automatic" \
    PRODUCT_BUNDLE_IDENTIFIER="BabaApp.Babaman.baba" \
    -allowProvisioningUpdates

if [ $? -ne 0 ]; then
    print_error "Build failed! This might be due to entitlements not supported by free account."
    print_info "Trying with minimal entitlements..."
    
    # Fallback 1: Build with minimal entitlements
    xcodebuild archive \
        -workspace "$WORKSPACE_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "generic/platform=iOS" \
        -archivePath "./build/Feather.xcarchive" \
        CODE_SIGN_ENTITLEMENTS="Feather/Supporting Files/Feather-Minimal.entitlements" \
        CODE_SIGN_STYLE="Automatic" \
        PRODUCT_BUNDLE_IDENTIFIER="BabaApp.Babaman.baba" \
        -allowProvisioningUpdates
    
    if [ $? -ne 0 ]; then
        print_error "Build with minimal entitlements also failed!"
        print_info "Trying without any entitlements file..."
        
        # Fallback 2: Build without entitlements
        xcodebuild archive \
            -workspace "$WORKSPACE_PATH" \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -destination "generic/platform=iOS" \
            -archivePath "./build/Feather.xcarchive" \
            CODE_SIGN_STYLE="Automatic" \
            PRODUCT_BUNDLE_IDENTIFIER="BabaApp.Babaman.baba" \
            -allowProvisioningUpdates
        
        if [ $? -ne 0 ]; then
            print_error "Build failed even without entitlements! Please check your Apple Developer account setup."
            print_info "Make sure you have:"
            print_info "1. Signed in to Xcode with your Apple ID"
            print_info "2. Selected your development team in Xcode project settings"
            print_info "3. A valid provisioning profile for BabaApp.Babaman.baba"
            exit 1
        fi
    fi
fi

print_success "Build completed successfully!"

# Create IPA
print_info "Creating IPA..."

# Create output directory
mkdir -p "./dist"

# Manual IPA creation (more reliable for free accounts)
print_info "Using manual IPA creation for better free account compatibility..."

# Extract the .app from archive
APP_PATH="./build/Feather.xcarchive/Products/Applications/Feather.app"

if [ ! -d "$APP_PATH" ]; then
    print_error "App not found in archive"
    exit 1
fi

# Create Payload directory
mkdir -p "./dist/Payload"

# Copy app
cp -R "$APP_PATH" "./dist/Payload/"

# Create IPA
cd "./dist"
zip -r "BabaApps-FreeBuild.ipa" "Payload"
cd ..

# Clean up
rm -rf "./dist/Payload"

if [ -f "./dist/BabaApps-FreeBuild.ipa" ]; then
    print_success "IPA created successfully: ./dist/BabaApps-FreeBuild.ipa"
    
    # Get IPA size
    IPA_SIZE=$(du -h "./dist/BabaApps-FreeBuild.ipa" | cut -f1)
    print_info "IPA size: $IPA_SIZE"
    
    # Check signing info
    print_info "Checking signing information..."
    if command -v codesign >/dev/null 2>&1; then
        unzip -q "./dist/BabaApps-FreeBuild.ipa" -d "./temp_check"
        codesign -vv -d "./temp_check/Payload/Feather.app" 2>&1 | head -5
        rm -rf "./temp_check"
    fi
else
    print_error "Failed to create IPA"
    exit 1
fi

# Clean up build artifacts
print_info "Cleaning up build artifacts..."
rm -rf "./build"

print_success "🎉 Build process completed successfully!"
print_info "Your IPA file is ready at: ./dist/BabaApps-FreeBuild.ipa"
print_info ""
print_info "📱 Installation Instructions for FREE account:"
print_info "1. Use AltStore, Sideloadly, or similar tools to install"
print_info "2. The app will work for 7 days before needing refresh"
print_info "3. Some advanced network features may be limited"
print_info ""
print_warning "💡 To unlock all features, consider upgrading to Apple Developer Program ($99/year)"
print_info "   This enables: Associated Domains, App Groups, Custom Protocols, and longer signing periods"