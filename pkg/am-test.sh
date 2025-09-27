#!/bin/bash
set -e

# Variables
PKGNAME="WoeUSB-ng"
PKGVERS="0.2.12"
APPIMAGE_NAME="WoeUSB-ng-x86_64.AppImage"
SRC_URL="https://github.com/WoeUSB/WoeUSB-ng/archive/v$PKGVERS.tar.gz"
PATCH_URL="https://gitlab.com/chaotic-aur/pkgbuilds/-/raw/main/woeusb-ng/pr79.patch"
WORKDIR="$(pwd)/$PKGNAME-build"
APPDIR="$WORKDIR/AppDir"
SHARUN="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh"
URUNTIME="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/uruntime2appimage.sh"

# Clean previous build
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
mkdir -p "$APPDIR/usr"

# Step 1: Download source, patch
cd "$WORKDIR"
wget -O "$PKGNAME-$PKGVERS.tar.gz" "$SRC_URL"
wget -O pr79.patch "$PATCH_URL"
tar -xzf "$PKGNAME-$PKGVERS.tar.gz"

# Step 2: Apply patch
cd "$PKGNAME-$PKGVERS"
patch --forward --strip=1 < ../pr79.patch || true

# Step 3: Build wheel using sharun
sharun_temp=$(mktemp -d)
cd "$sharun_temp"
cp -r "$WORKDIR/$PKGNAME-$PKGVERS" .
cd "$PKGNAME-$PKGVERS"

# Download sharun
wget --retry-connrefused --tries=10 "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun

# Run sharun with proper working directory and Python build
# Ensures AppDir/usr exists first
mkdir -p "$APPDIR/usr"
./quick-sharun bash -c "
  set -e
  export APPDIR='$APPDIR'
  python3 -m pip install --upgrade pip setuptools wheel build installer termcolor wxPython &&
  python3 -m build --wheel --no-isolation &&
  python3 -m installer --destdir='\$APPDIR/usr' dist/*.whl
"

# Step 4: Install desktop file and policy
mkdir -p "$APPDIR/usr/share/applications"
cp miscellaneous/WoeUSB-ng.desktop "$APPDIR/usr/share/applications/"
chmod 755 "$APPDIR/usr/share/applications/WoeUSB-ng.desktop"

mkdir -p "$APPDIR/usr/share/polkit-1/actions"
cp miscellaneous/com.github.woeusb.woeusb-ng.policy "$APPDIR/usr/share/polkit-1/actions/"

# Step 5: Create AppRun launcher
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="$HERE/usr/bin:$PATH"
export PYTHONPATH="$HERE/usr/lib/python3.12/site-packages:$PYTHONPATH"
exec "$HERE/usr/bin/woeusb" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Step 6: (Optional) copy icon if available
# mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
# cp path/to/icon.png "$APPDIR/usr/share/icons/hicolor/256x256/apps/WoeUSB-ng.png"

# Step 7: Build AppImage with uruntime
wget --retry-connrefused --tries=10 "$URUNTIME" -O ./uruntime2appimage
chmod +x ./uruntime2appimage
./uruntime2appimage "$APPDIR"

echo "✅ AppImage created: $WORKDIR/$APPIMAGE_NAME"
