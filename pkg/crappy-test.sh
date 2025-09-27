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

# Clean
rm -rf "$WORKDIR"
mkdir -p "$APPDIR/usr"

# Step 1: Download source, patch, policy
cd "$WORKDIR"
wget -O "$PKGNAME-$PKGVERS.tar.gz" "$SRC_URL"
wget -O pr79.patch "$PATCH_URL"
wget -O com.github.woeusb.woeusb-ng.policy "$POLICY_URL"
tar -xzf "$PKGNAME-$PKGVERS.tar.gz"

# Step 2: Apply patch
cd "$PKGNAME-$PKGVERS"
patch --forward --strip=1 < ../pr79.patch || true

# Step 3: Create Python venv in AppDir
python3 -m venv "$APPDIR/usr/venv"
source "$APPDIR/usr/venv/bin/activate"
pip install --upgrade pip setuptools wheel installer termcolor

# Step 4: Build and install wheels into venv
python -m build --wheel --no-isolation
python -m installer --destdir="$APPDIR/usr" dist/*.whl

# Install wxPython manually into venv
WX_WHL="wxpython-4.2.3-cp312-cp312-linux_x86_64.whl"
wget -O "$WX_WHL" "https://extras.wxpython.org/wxPython4/extras/linux/gtk3/ubuntu-24.04/$WX_WHL"
python -m installer --destdir="$APPDIR/usr" "$WX_WHL"

deactivate

# Step 5: Copy desktop file manually into AppDir
DESKTOP_SRC="$WORKDIR/$PKGNAME-$PKGVERS/miscellaneous/WoeUSB-ng.desktop"
if [ ! -f "$DESKTOP_SRC" ]; then
    echo "Error: Desktop file missing at $DESKTOP_SRC"
    exit 1
fi
mkdir -p "$APPDIR/usr/share/applications"
cp "$DESKTOP_SRC" "$APPDIR/usr/share/applications/"
chmod 644 "$APPDIR/usr/share/applications/WoeUSB-ng.desktop"

# Step 6: Copy polkit policy manually
POLICY_SRC="$WORKDIR/com.github.woeusb.woeusb-ng.policy"
mkdir -p "$APPDIR/usr/share/polkit-1/actions"
cp "$POLICY_SRC" "$APPDIR/usr/share/polkit-1/actions/"

# Step 7: Create AppRun launcher
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="$HERE/usr/venv/bin:$PATH"
export PYTHONPATH="$HERE/usr/lib/python3.12/site-packages:$PYTHONPATH"
exec "$HERE/usr/venv/bin/woeusb" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Step 8: Download AppImageTool and build
cd "$WORKDIR"
wget -O appimagetool-x86_64.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
./appimagetool-x86_64.AppImage "$APPDIR" "$WORKDIR/$APPIMAGE_NAME"
