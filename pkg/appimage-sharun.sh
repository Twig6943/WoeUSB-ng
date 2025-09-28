#!/bin/bash
set -e

# --- Paths ---
ROOT=$(pwd)
BUILD="$ROOT/WoeUSB-ng-build"
APPDIR="$BUILD/AppDir"
SRC="$BUILD/WoeUSB-ng"

echo "Root: $ROOT"
echo "Build dir: $BUILD"
echo "AppDir: $APPDIR"
echo "Source dir: $SRC"

# --- Clean previous build ---
rm -rf "$BUILD"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"

# --- Step 1: Clone repository and apply patch ---
git clone https://github.com/Twig6943/WoeUSB-ng.git "$SRC"
cd "$SRC"
wget -O "pr79.patch" "https://gitlab.com/chaotic-aur/pkgbuilds/-/raw/main/woeusb-ng/pr79.patch"
patch --forward --strip=1 < pr79.patch || true

# --- Step 2: Detect Python version ---
PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Using Python version $PYVER"

# --- Step 3: Copy WoeUSB source ---
if [ ! -d "$SRC/src/WoeUSB" ]; then
    echo "Error: WoeUSB source folder not found at $SRC/src/WoeUSB"
    exit 1
fi
mkdir -p "$APPDIR/usr/lib/python${PYVER}/site-packages/"
cp -r "$SRC/src/WoeUSB" "$APPDIR/usr/lib/python${PYVER}/site-packages/"
touch "$APPDIR/usr/lib/python${PYVER}/site-packages/WoeUSB/__init__.py"

# --- Step 4: Create woeusbgui launcher ---
mkdir -p "$APPDIR/usr/bin"
cat > "$APPDIR/usr/bin/woeusbgui" << 'EOF'
#!/bin/bash
PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
export PYTHONPATH="$(dirname "$(dirname "$(readlink -f "${0}")")")/lib/python${PYVER}/site-packages:$PYTHONPATH"
exec python3 -m WoeUSB.gui "$@"
EOF
chmod +x "$APPDIR/usr/bin/woeusbgui"

# --- Step 5: Copy desktop, logo, polkit ---
mkdir -p "$APPDIR/usr/share/applications"
cp "$SRC/miscellaneous/WoeUSB-ng.desktop" "$APPDIR/"
cp "$SRC/miscellaneous/WoeUSB-ng.desktop" "$APPDIR/usr/share/applications/"
chmod 644 "$APPDIR/WoeUSB-ng.desktop" "$APPDIR/usr/share/applications/WoeUSB-ng.desktop"

cp "$SRC/miscellaneous/woeusb-logo.png" "$APPDIR/"
mkdir -p "$APPDIR/usr/share/polkit-1/actions"
cp "$SRC/miscellaneous/com.github.woeusb.woeusb-ng.policy" "$APPDIR/usr/share/polkit-1/actions/"

# --- Step 6: Create AppRun ---
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
export PYTHONPATH="$HERE/usr/lib/python${PYVER}/site-packages:$PYTHONPATH"
exec python3 "$HERE/usr/bin/woeusbgui" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# --- Step 7: Debug: list AppDir contents ---
echo "Contents of AppDir:"
ls -R "$APPDIR"

# --- Step 8: Download AppImageTool and build AppImage ---
cd "$BUILD"
wget -O "appimagetool-x86_64.AppImage" \
"https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
chmod +x "appimagetool-x86_64.AppImage"

APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 ./appimagetool-x86_64.AppImage "$APPDIR" "WoeUSB-ng-x86_64.AppImage"
