#!/bin/bash
set -e

# Variables
PKGNAME="WoeUSB-ng"
PKGVERS="0.2.12"
APPIMAGE_NAME="WoeUSB-ng-x86_64.AppImage"
SRC_URL="https://github.com/WoeUSB/WoeUSB-ng/archive/v$PKGVERS.tar.gz"
PATCH_URL="https://gitlab.com/chaotic-aur/pkgbuilds/-/raw/main/woeusb-ng/pr79.patch"
POLICY_URL="https://gitlab.com/chaotic-aur/pkgbuilds/-/raw/main/woeusb-ng/com.github.woeusb.woeusb-ng.policy"
WORKDIR="$(pwd)/$PKGNAME-build"
APPDIR="$WORKDIR/AppDir"

# Clean previous build
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
mkdir -p "$APPDIR/usr"

# Step 1: Download source, patch, and policy
cd "$WORKDIR"
wget -O "$PKGNAME-$PKGVERS.tar.gz" "$SRC_URL"
wget -O pr79.patch "$PATCH_URL"
wget -O com.github.woeusb.woeusb-ng.policy "$POLICY_URL"
tar -xzf "$PKGNAME-$PKGVERS.tar.gz"

# Step 2: Apply patch
cd "$PKGNAME-$PKGVERS"
patch --forward --strip=1 < ../pr79.patch || true

# Step 3: Build wheel using sharun
# Install dependencies and build in an isolated environment
sharun python3 -m pip install --upgrade pip setuptools wheel build installer termcolor wxPython
sharun python3 -m build --wheel --no-isolation

# Step 4: Install wheel into AppDir using sharun installer
mkdir -p "$APPDIR/usr"
sharun python3 -m installer --destdir="$APPDIR/usr" dist/*.whl

# Step 5: Install desktop file and policy
mkdir -p "$APPDIR/usr/share/applications"
cp miscellaneous/WoeUSB-ng.desktop "$APPDIR/usr/share/applications/"
chmod 755 "$APPDIR/usr/share/applications/WoeUSB-ng.desktop"

mkdir -p "$APPDIR/usr/share/polkit-1/actions"
cp ../com.github.woeusb.woeusb-ng.policy "$APPDIR/usr/share/polkit-1/actions/"

# Step 6: Create AppRun launcher
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="$HERE/usr/bin:$PATH"
export PYTHONPATH="$HERE/usr/lib/python3.12/site-packages:$PYTHONPATH"
exec "$HERE/usr/bin/woeusb" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Step 7: (Optional) copy icon if available
# mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
# cp path/to/icon.png "$APPDIR/usr/share/icons/hicolor/256x256/apps/WoeUSB-ng.png"

# Step 8: Download AppImageTool and build AppImage
wget -O appimagetool.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool.AppImage
./appimagetool.AppImage "$APPDIR"

echo "✅ AppImage created: $WORKDIR/$APPIMAGE_NAME"
