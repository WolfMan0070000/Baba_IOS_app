# BabaApps IPA Builder for FREE Apple Developer Accounts (PowerShell)
# این اسکریپت برای اکانت‌های رایگان طراحی شده است

param(
    [string]$Configuration = "Release",
    [string]$Scheme = "Feather"
)

# Configuration
$ProjectPath = "Feather.xcodeproj"
$WorkspacePath = "Feather.xcworkspace"
$EntitlementsPath = "Feather/Supporting Files/Feather.entitlements"

function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Info($message) {
    Write-ColorOutput Blue "[INFO] $message"
}

function Write-Success($message) {
    Write-ColorOutput Green "[SUCCESS] $message"
}

function Write-Warning($message) {
    Write-ColorOutput Yellow "[WARNING] $message"
}

function Write-Error($message) {
    Write-ColorOutput Red "[ERROR] $message"
}

# Welcome message for free account users
Write-Info "🆓 Building BabaApps IPA for FREE Apple Developer Account"
Write-Warning "⚠️  Note: Some advanced features may be limited due to free account restrictions"

# Check if we're in the correct directory
if (!(Test-Path "$ProjectPath/project.pbxproj")) {
    Write-Error "Project file not found. Please run this script from the iOS app directory."
    exit 1
}

# Check if entitlements file exists
if (!(Test-Path $EntitlementsPath)) {
    Write-Error "Entitlements file not found at $EntitlementsPath"
    exit 1
}

Write-Info "Building with simplified entitlements for free account..."

# Clean previous builds
Write-Info "Cleaning previous builds..."
& xcodebuild clean -workspace $WorkspacePath -scheme $Scheme -configuration $Configuration

# Create build directory
New-Item -ItemType Directory -Force -Path "./build" | Out-Null

# Build for device with automatic signing
Write-Info "Building for device with automatic signing..."
$buildArgs = @(
    "archive",
    "-workspace", $WorkspacePath,
    "-scheme", $Scheme,
    "-configuration", $Configuration,
    "-destination", "generic/platform=iOS",
    "-archivePath", "./build/Feather.xcarchive",
    "CODE_SIGN_ENTITLEMENTS=$EntitlementsPath",
    "CODE_SIGN_STYLE=Automatic",
    "DEVELOPMENT_TEAM=",
    "PRODUCT_BUNDLE_IDENTIFIER=BabaApp.Babaman.baba"
)

& xcodebuild @buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed! This might be due to entitlements not supported by free account."
    Write-Info "Trying with minimal entitlements..."
    
    # Fallback 1: Build with minimal entitlements
    $minimalArgs = @(
        "archive",
        "-workspace", $WorkspacePath,
        "-scheme", $Scheme,
        "-configuration", $Configuration,
        "-destination", "generic/platform=iOS",
        "-archivePath", "./build/Feather.xcarchive",
        "CODE_SIGN_ENTITLEMENTS=Feather/Supporting Files/Feather-Minimal.entitlements",
        "CODE_SIGN_STYLE=Automatic",
        "DEVELOPMENT_TEAM=",
        "PRODUCT_BUNDLE_IDENTIFIER=BabaApp.Babaman.baba"
    )
    
    & xcodebuild @minimalArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build with minimal entitlements also failed!"
        Write-Info "Trying without any entitlements file..."
        
        # Fallback 2: Build without entitlements
        $noEntitlementsArgs = @(
            "archive",
            "-workspace", $WorkspacePath,
            "-scheme", $Scheme,
            "-configuration", $Configuration,
            "-destination", "generic/platform=iOS",
            "-archivePath", "./build/Feather.xcarchive",
            "CODE_SIGN_STYLE=Automatic",
            "DEVELOPMENT_TEAM=",
            "PRODUCT_BUNDLE_IDENTIFIER=BabaApp.Babaman.baba"
        )
        
        & xcodebuild @noEntitlementsArgs
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Build failed even without entitlements! Please check your Apple Developer account setup."
            Write-Info "Make sure you have:"
            Write-Info "1. Signed in to Xcode with your Apple ID"
            Write-Info "2. Selected your development team in Xcode project settings"
            Write-Info "3. A valid provisioning profile for BabaApp.Babaman.baba"
            exit 1
        }
    }
}

Write-Success "Build completed successfully!"

# Create IPA
Write-Info "Creating IPA..."

# Create output directory
New-Item -ItemType Directory -Force -Path "./dist" | Out-Null

# Manual IPA creation (more reliable for free accounts)
Write-Info "Using manual IPA creation for better free account compatibility..."

# Extract the .app from archive
$appPath = "./build/Feather.xcarchive/Products/Applications/Feather.app"

if (!(Test-Path $appPath)) {
    Write-Error "App not found in archive"
    exit 1
}

# Create Payload directory
New-Item -ItemType Directory -Force -Path "./dist/Payload" | Out-Null

# Copy app
Copy-Item -Path $appPath -Destination "./dist/Payload/" -Recurse -Force

# Create IPA using PowerShell's compression
Write-Info "Creating IPA archive..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory("./dist/Payload", "./dist/BabaApps-FreeBuild.ipa")

# Clean up
Remove-Item -Path "./dist/Payload" -Recurse -Force

if (Test-Path "./dist/BabaApps-FreeBuild.ipa") {
    Write-Success "IPA created successfully: ./dist/BabaApps-FreeBuild.ipa"
    
    # Get IPA size
    $ipaSize = (Get-Item "./dist/BabaApps-FreeBuild.ipa").Length
    $ipaSizeMB = [math]::Round($ipaSize / 1MB, 2)
    Write-Info "IPA size: $ipaSizeMB MB"
    
    # Check signing info
    Write-Info "Checking signing information..."
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory("./dist/BabaApps-FreeBuild.ipa", "./temp_check")
        $signingInfo = & codesign -vv -d "./temp_check/Payload/Feather.app" 2>&1
        if ($signingInfo) {
            $signingInfo[0..4] | Write-Output
        }
        Remove-Item -Path "./temp_check" -Recurse -Force
    }
    catch {
        Write-Warning "Could not verify signing information"
    }
}
else {
    Write-Error "Failed to create IPA"
    exit 1
}

# Clean up build artifacts
Write-Info "Cleaning up build artifacts..."
Remove-Item -Path "./build" -Recurse -Force -ErrorAction SilentlyContinue

Write-Success "🎉 Build process completed successfully!"
Write-Info "Your IPA file is ready at: ./dist/BabaApps-FreeBuild.ipa"
Write-Info ""
Write-Info "📱 Installation Instructions for FREE account:"
Write-Info "1. Use AltStore, Sideloadly, or similar tools to install"
Write-Info "2. The app will work for 7 days before needing refresh"
Write-Info "3. Some advanced network features may be limited"
Write-Info ""
Write-Warning "💡 To unlock all features, consider upgrading to Apple Developer Program (`$99/year)"
Write-Info "   This enables: Associated Domains, App Groups, Custom Protocols, and longer signing periods"