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

# --- Step 2b: Create virtual environment for dependencies ---
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip

# Install all Python dependencies
pip install \
    wxPython==4.2.3 \
    installer \
    setuptools \
    wheel \
    build \
    termcolor

# --- Step 3: Install all Python packages into AppDir ---
mkdir -p "$APPDIR/usr/lib/python${PYVER}/site-packages"
VENV_LIB=".venv/lib/python${PYVER}/site-packages"
cp -r $VENV_LIB/* "$APPDIR/usr/lib/python${PYVER}/site-packages/"

# --- Step 4: Copy WoeUSB source code ---
if [ ! -d "$SRC/src/WoeUSB" ]; then
    echo "Error: WoeUSB source folder not found at $SRC/src/WoeUSB"
    exit 1
fi
cp -r "$SRC/src/WoeUSB" "$APPDIR/usr/lib/python${PYVER}/site-packages/"
touch "$APPDIR/usr/lib/python${PYVER}/site-packages/WoeUSB/__init__.py"

# --- Step 5: Create woeusbgui launcher ---
mkdir -p "$APPDIR/usr/bin"
cat > "$APPDIR/usr/bin/woeusbgui" << 'EOF'
#!/bin/bash
PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
export PYTHONPATH="$(dirname "$(dirname "$(readlink -f "${0}")")")/lib/python${PYVER}/site-packages:$PYTHONPATH"
exec python3 -m WoeUSB.gui "$@"
EOF
chmod +x "$APPDIR/usr/bin/woeusbgui"

# --- Step 6: Copy desktop, logo, polkit ---
mkdir -p "$APPDIR/usr/share/applications"
cp "$SRC/miscellaneous/WoeUSB-ng.desktop" "$APPDIR/"
cp "$SRC/miscellaneous/WoeUSB-ng.desktop" "$APPDIR/usr/share/applications/"
chmod 644 "$APPDIR/WoeUSB-ng.desktop" "$APPDIR/usr/share/applications/WoeUSB-ng.desktop"

cp "$SRC/miscellaneous/woeusb-logo.png" "$APPDIR/"
mkdir -p "$APPDIR/usr/share/polkit-1/actions"
cp "$SRC/miscellaneous/com.github.woeusb.woeusb-ng.policy" "$APPDIR/usr/share/polkit-1/actions/"

# --- Step 7: Create AppRun ---
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
export PYTHONPATH="$HERE/usr/lib/python${PYVER}/site-packages:$PYTHONPATH"
exec python3 "$HERE/usr/bin/woeusbgui" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# --- Step 8: Debug: list AppDir contents ---
echo "Contents of AppDir before building:"
ls -R "$APPDIR"

# --- Step 9: Download AppImageTool ---
cd "$BUILD"
wget -O "appimagetool-x86_64.AppImage" \
"https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
chmod +x "appimagetool-x86_64.AppImage"

# --- Step 10: Build AppImage in non-FUSE mode ---
./appimagetool-x86_64.AppImage "$APPDIR" "WoeUSB-ng-x86_64.AppImage" --no-appstream

echo "✅ AppImage built successfully: $BUILD/WoeUSB-ng-x86_64.AppImage"
