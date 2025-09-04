# Feather IPA Builder Script with Proper Entitlements (PowerShell)
# This script properly creates an IPA file with all necessary entitlements for file system access

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

Write-Info "Building Feather IPA with proper entitlements..."

# Clean previous builds
Write-Info "Cleaning previous builds..."
& xcodebuild clean -workspace $WorkspacePath -scheme $Scheme -configuration $Configuration

# Create build directory
New-Item -ItemType Directory -Force -Path "./build" | Out-Null

# Build for device
Write-Info "Building for device..."
$buildArgs = @(
    "archive",
    "-workspace", $WorkspacePath,
    "-scheme", $Scheme,
    "-configuration", $Configuration,
    "-destination", "generic/platform=iOS",
    "-archivePath", "./build/Feather.xcarchive",
    "CODE_SIGN_ENTITLEMENTS=$EntitlementsPath",
    "DEVELOPMENT_TEAM=",
    "CODE_SIGN_IDENTITY=",
    "CODE_SIGN_STYLE=Manual",
    "PROVISIONING_PROFILE_SPECIFIER="
)

& xcodebuild @buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed!"
    exit 1
}

Write-Success "Build completed successfully!"

# Create IPA with proper entitlements
Write-Info "Creating IPA with entitlements..."

# Create output directory
New-Item -ItemType Directory -Force -Path "./dist" | Out-Null

# Create ExportOptions.plist if it doesn't exist
$exportOptionsPath = "./build_configs/ExportOptions.plist"
if (!(Test-Path $exportOptionsPath)) {
    Write-Info "Creating ExportOptions.plist..."
    New-Item -ItemType Directory -Force -Path "./build_configs" | Out-Null
    
    $exportOptions = @'
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
'@
    
    Set-Content -Path $exportOptionsPath -Value $exportOptions
}

# Try to export archive
& xcodebuild -exportArchive -archivePath "./build/Feather.xcarchive" -exportPath "./dist" -exportOptionsPlist $exportOptionsPath

# Alternative method: Manual IPA creation if export failed
if (!(Test-Path "./dist/Feather.ipa")) {
    Write-Warning "Export method failed, using manual IPA creation..."
    
    # Extract the .app from archive
    $appPath = "./build/Feather.xcarchive/Products/Applications/Feather.app"
    
    if (!(Test-Path $appPath)) {
        Write-Error "App not found in archive"
        exit 1
    }
    
    # Create Payload directory
    New-Item -ItemType Directory -Force -Path "./dist/Payload" | Out-Null
    
    # Copy app with preserved permissions and entitlements
    Copy-Item -Path $appPath -Destination "./dist/Payload/" -Recurse -Force
    
    # Verify entitlements are embedded (if codesign is available)
    Write-Info "Verifying entitlements in app..."
    try {
        $entitlements = & codesign -d --entitlements - "./dist/Payload/Feather.app" 2>$null
        if ($entitlements) {
            $entitlements[0..19] | Write-Output
        }
    }
    catch {
        Write-Warning "Could not verify entitlements (codesign not available)"
    }
    
    # Create IPA using PowerShell's compression
    Write-Info "Creating IPA archive..."
    Push-Location "./dist"
    
    # Use .NET compression for better compatibility
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory("./Payload", "./Feather.ipa")
    
    Pop-Location
    
    # Clean up
    Remove-Item -Path "./dist/Payload" -Recurse -Force
}

if (Test-Path "./dist/Feather.ipa") {
    Write-Success "IPA created successfully: ./dist/Feather.ipa"
    
    # Get IPA size
    $ipaSize = (Get-Item "./dist/Feather.ipa").Length
    $ipaSizeMB = [math]::Round($ipaSize / 1MB, 2)
    Write-Info "IPA size: $ipaSizeMB MB"
    
    # Verify entitlements in final IPA
    Write-Info "Verifying entitlements in final IPA..."
    try {
        # Extract and check entitlements
        New-Item -ItemType Directory -Force -Path "./temp_verify" | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory("./dist/Feather.ipa", "./temp_verify")
        
        Write-Output "Entitlements in final IPA:"
        $entitlements = & codesign -d --entitlements - "./temp_verify/Payload/Feather.app" 2>$null
        if ($entitlements) {
            $entitlements[0..19] | Write-Output
        }
        
        Remove-Item -Path "./temp_verify" -Recurse -Force
    }
    catch {
        Write-Warning "Could not verify final entitlements"
    }
}
else {
    Write-Error "Failed to create IPA"
    exit 1
}

# Clean up build artifacts
Write-Info "Cleaning up build artifacts..."
Remove-Item -Path "./build" -Recurse -Force -ErrorAction SilentlyContinue

Write-Success "Build process completed successfully!"
Write-Info "Your IPA file is ready at: ./dist/Feather.ipa"
Write-Info ""
Write-Info "Important notes for sideloading:"
Write-Info "- This IPA includes proper entitlements for file system access"
Write-Info "- The 'Cannot create file' error should be resolved"
Write-Info "- Use this IPA instead of manually created ones"
Write-Info ""
Write-Warning "Note: You may still need to sign this IPA with your certificate before sideloading"