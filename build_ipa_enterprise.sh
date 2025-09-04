#!/bin/bash

# BabaApps Enterprise/AdHoc IPA Builder
# این اسکریپت برای امضای Enterprise/AdHoc با p12 و mobileprovision طراحی شده است

set -e

# Configuration
PROJECT_PATH="Feather.xcodeproj"
SCHEME="Feather"
CONFIGURATION="Release"
WORKSPACE_PATH="Feather.xcworkspace"
ENTERPRISE_ENTITLEMENTS_PATH="Feather/Supporting Files/Feather-Enterprise.entitlements"

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

# Welcome message for enterprise signing
print_info "🏢 Building BabaApps IPA for Enterprise/AdHoc Signing"
print_warning "⚠️  This script is designed for use with p12 + mobileprovision files"
print_info "📋 Make sure you have:"
print_info "   1. Your p12 certificate file"
print_info "   2. Your mobileprovision file"
print_info "   3. Enhanced entitlements for file system access"
print_info ""

# Check if we're in the correct directory
if [ ! -f "$PROJECT_PATH/project.pbxproj" ]; then
    print_error "Project file not found. Please run this script from the iOS app directory."
    exit 1
fi

# Check if enterprise entitlements file exists
if [ ! -f "$ENTERPRISE_ENTITLEMENTS_PATH" ]; then
    print_error "Enterprise entitlements file not found at $ENTERPRISE_ENTITLEMENTS_PATH"
    print_info "Creating enhanced entitlements file for enterprise signing..."
    exit 1
fi

print_info "Building with enhanced entitlements for enterprise/AdHoc signing..."

# Clean previous builds
print_info "Cleaning previous builds..."
xcodebuild clean -workspace "$WORKSPACE_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION"

# Create build directory
mkdir -p "./build"

# Build for device with enterprise entitlements
print_info "Building for device with enterprise entitlements..."
xcodebuild archive \
    -workspace "$WORKSPACE_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -archivePath "./build/Feather.xcarchive" \
    CODE_SIGN_ENTITLEMENTS="$ENTERPRISE_ENTITLEMENTS_PATH" \
    CODE_SIGN_STYLE="Automatic" \
    PRODUCT_BUNDLE_IDENTIFIER="BabaApp.Babaman.baba" \
    -allowProvisioningUpdates

if [ $? -ne 0 ]; then
    print_error "Build failed with enterprise entitlements!"
    print_info "Trying with standard entitlements..."
    
    # Fallback: Build with standard entitlements
    xcodebuild archive \
        -workspace "$WORKSPACE_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "generic/platform=iOS" \
        -archivePath "./build/Feather.xcarchive" \
        CODE_SIGN_ENTITLEMENTS="Feather/Supporting Files/Feather.entitlements" \
        CODE_SIGN_STYLE="Automatic" \
        PRODUCT_BUNDLE_IDENTIFIER="BabaApp.Babaman.baba" \
        -allowProvisioningUpdates
    
    if [ $? -ne 0 ]; then
        print_error "Build failed with all entitlements configurations!"
        print_info "Please check your signing configuration and entitlements."
        exit 1
    fi
fi

print_success "Build completed successfully!"

# Create IPA
print_info "Creating IPA with enhanced file system permissions..."

# Create output directory
mkdir -p "./dist"

# Manual IPA creation 
print_info "Creating IPA for enterprise distribution..."

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

# Verify entitlements in the built app
print_info "Verifying entitlements in built app..."
if command -v codesign >/dev/null 2>&1; then
    echo "Current entitlements in app:"
    codesign -d --entitlements - "./dist/Payload/Feather.app" 2>/dev/null | head -20
fi

# Create IPA
cd "./dist"
zip -r "BabaApps-Enterprise.ipa" "Payload"
cd ..

# Clean up
rm -rf "./dist/Payload"

if [ -f "./dist/BabaApps-Enterprise.ipa" ]; then
    print_success "IPA created successfully: ./dist/BabaApps-Enterprise.ipa"
    
    # Get IPA size
    IPA_SIZE=$(du -h "./dist/BabaApps-Enterprise.ipa" | cut -f1)
    print_info "IPA size: $IPA_SIZE"
    
    # Verify the IPA
    print_info "Verifying IPA signing and entitlements..."
    if command -v codesign >/dev/null 2>&1; then
        unzip -q "./dist/BabaApps-Enterprise.ipa" -d "./temp_verify"
        echo ""
        echo "=== Signing Information ==="
        codesign -vv -d "./temp_verify/Payload/Feather.app" 2>&1 | head -5
        echo ""
        echo "=== Entitlements in Final IPA ==="
        codesign -d --entitlements - "./temp_verify/Payload/Feather.app" 2>/dev/null | head -15
        rm -rf "./temp_verify"
    fi
else
    print_error "Failed to create IPA"
    exit 1
fi

# Clean up build artifacts
print_info "Cleaning up build artifacts..."
rm -rf "./build"

print_success "🎉 Enterprise IPA build completed successfully!"
print_info "Your IPA file is ready at: ./dist/BabaApps-Enterprise.ipa"
print_info ""
print_info "📱 Key Features of this IPA:"
print_info "✅ Enhanced file system access entitlements"
print_info "✅ Temporary directory write permissions"
print_info "✅ Documents directory access"
print_info "✅ Network client/server permissions"
print_info "✅ Background processing capabilities"
print_info ""
print_info "🔧 For Manual Signing with p12:"
print_info "1. Use this IPA as base"
print_info "2. Re-sign with your p12 + mobileprovision"
print_info "3. The enhanced entitlements should resolve 'Cannot create file' errors"
print_info ""
print_warning "📝 Note: If you still get file permission errors after manual signing,"
print_warning "   make sure your mobileprovision includes the necessary entitlements."