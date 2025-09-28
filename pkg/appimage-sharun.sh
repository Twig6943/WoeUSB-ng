#!/bin/bash
set -e

# Remove any previous build
rm -rf "./WoeUSB-ng-build"
mkdir -p "./WoeUSB-ng-build/AppDir/usr"

# Step 1: Clone repository and apply patch
cd "./WoeUSB-ng-build"
git clone https://github.com/Twig6943/WoeUSB-ng.git
cd "WoeUSB-ng"
wget -O "pr79.patch" "https://gitlab.com/chaotic-aur/pkgbuilds/-/raw/main/woeusb-ng/pr79.patch"
patch --forward --strip=1 < pr79.patch || true

# Step 2: Detect Python version
PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")

# Step 3: Copy WoeUSB source into AppDir
mkdir -p "../AppDir/usr/lib/python${PYVER}/site-packages/"
cp -r src/WoeUSB "../AppDir/usr/lib/python${PYVER}/site-packages/"
# Ensure __init__.py exists
touch "../AppDir/usr/lib/python${PYVER}/site-packages/WoeUSB/__init__.py"

# Step 4: Create a small woeusbgui launcher in AppDir/usr/bin
mkdir -p "../AppDir/usr/bin"
cat > "../AppDir/usr/bin/woeusbgui" << 'EOF'
#!/bin/bash
PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
export PYTHONPATH="$(dirname "$(dirname "$(readlink -f "${0}")")")/lib/python${PYVER}/site-packages:$PYTHONPATH"
exec python3 -m WoeUSB.gui "$@"
EOF
chmod +x "../AppDir/usr/bin/woeusbgui"

# Step 5: Copy desktop file
mkdir -p "../AppDir/usr/share/applications"
cp "miscellaneous/WoeUSB-ng.desktop" "../AppDir/"
cp "miscellaneous/WoeUSB-ng.desktop" "../AppDir/usr/share/applications/"
chmod 644 "../AppDir/WoeUSB-ng.desktop" "../AppDir/usr/share/applications/WoeUSB-ng.desktop"

# Step 6: Copy logo
cp "miscellaneous/woeusb-logo.png" "../AppDir/"

# Step 7: Copy polkit policy
mkdir -p "../AppDir/usr/share/polkit-1/actions"
cp "miscellaneous/com.github.woeusb.woeusb-ng.policy" "../AppDir/usr/share/polkit-1/actions/"

# Step 8: Create AppRun launcher
cat > "../AppDir/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
export PYTHONPATH="$HERE/usr/lib/python${PYVER}/site-packages:$PYTHONPATH"
exec python3 "$HERE/usr/bin/woeusbgui" "$@"
EOF
chmod +x "../AppDir/AppRun"

# Step 9: Download AppImageTool and build AppImage
cd ..
wget -O "appimagetool-x86_64.AppImage" \
"https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
chmod +x "appimagetool-x86_64.AppImage"

APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 ./appimagetool-x86_64.AppImage "AppDir" "WoeUSB-ng-x86_64.AppImage"
