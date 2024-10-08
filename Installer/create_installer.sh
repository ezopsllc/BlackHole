#!/usr/bin/env bash

# Creates installer for different channel versions.
# Run this script from the local BlackHole repo's root directory.
# If this script is not executable from the Terminal,
# it may need execute permissions first by running this command:
#   chmod +x create_installer.sh

driverName="BlackHole"
notarize=false # Notarization is disabled in this version

############################################################################

# Basic Validation
if [ ! -d BlackHole.xcodeproj ]; then
    echo "This script must be run from the BlackHole repo root folder."
    echo "For example:"
    echo "  cd /path/to/BlackHole"
    echo "  ./Installer/create_installer.sh"
    exit 1
fi

version=`cat VERSION`

#Version Validation
if [ -z "$version" ]; then
    echo "Could not find version number. VERSION file is missing from repo root or is empty."
    exit 1
fi

for channels in 2; do #16 64 128 256; do
    # Env
    ch=$channels"ch"
    driverVartiantName=$driverName$ch
    bundleID="audio.existential.$driverVartiantName"
    
    # Build
    xcodebuild \
      -project BlackHole.xcodeproj \
      -configuration Release \
      -target BlackHole CONFIGURATION_BUILD_DIR=build \
      PRODUCT_BUNDLE_IDENTIFIER=$bundleID \
      GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS
      kNumber_Of_Channels='$channels'
      kPlugIn_BundleID=\"'$bundleID'\"
      kDriver_Name=\"'$driverName'\"' \
      CODE_SIGN_IDENTITY="" \
      CODE_SIGNING_REQUIRED=NO
    
    if [ ! -f build/BlackHole.driver/Contents/Info.plist ]; then
        echo "Build failed: Info.plist not found"
        exit 1
    fi

    # Generate a new UUID
    uuid=$(uuidgen)
    awk '{sub(/e395c745-4eea-4d94-bb92-46224221047c/,"'$uuid'")}1' build/BlackHole.driver/Contents/Info.plist > Temp.plist
    mv Temp.plist build/BlackHole.driver/Contents/Info.plist
    
    mkdir -p Installer/root
    driverBundleName=$driverVartiantName.driver
    mv build/BlackHole.driver Installer/root/$driverBundleName
    rm -r build
    
    # Create package with pkgbuild
    chmod 755 Installer/Scripts/preinstall
    chmod 755 Installer/Scripts/postinstall
    
    pkgbuild \
      --root Installer/root \
      --scripts Installer/Scripts \
      --identifier $bundleID \
      --version $version \
      --install-location /Library/Audio/Plug-Ins/HAL \
      "Installer/$driverName.pkg"
    rm -r Installer/root
    
    # Create installer with productbuild
    cd Installer
    
    echo "<?xml version=\"1.0\" encoding='utf-8'?>
    <installer-gui-script minSpecVersion='2'>
        <title>$driverName: Audio Loopback Driver ($ch) $version</title>
        <welcome file='welcome.html'/>
        <license file='../LICENSE'/>
        <conclusion file='conclusion.html'/>
        <domains enable_anywhere='false' enable_currentUserHome='false' enable_localSystem='true'/>
        <pkg-ref id=\"$bundleID\"/>
        <options customize='never' require-scripts='false' hostArchitectures='x86_64,arm64'/>
        <volume-check>
            <allowed-os-versions>
                <os-version min='10.13'/>
            </allowed-os-versions>
        </volume-check>
        <choices-outline>
            <line choice=\"$bundleID\"/>
        </choices-outline>
        <choice id=\"$bundleID\" visible='true' title=\"$driverName $ch\" start_selected='true'>
            <pkg-ref id=\"$bundleID\"/>
        </choice>
        <pkg-ref id=\"$bundleID\" version=\"$version\" onConclusion='none'>$driverName.pkg</pkg-ref>
    </installer-gui-script>" >> distribution.xml
    
    # Build
    installerPkgName="$driverVartiantName-$version.pkg"
    productbuild \
      --distribution distribution.xml \
      --resources . \
      --package-path $driverName.pkg $installerPkgName
    rm distribution.xml
    rm -f $driverName.pkg

    cd ..
done
