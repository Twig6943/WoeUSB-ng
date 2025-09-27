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

# Step 3: Create Python venv in AppDir
python3 -m venv "$APPDIR/usr/venv"
source "$APPDIR/usr/venv/bin/activate"

# Step 4: Upgrade pip and install packages inside the venv
"$APPDIR/usr/venv/bin/pip" install --upgrade pip
"$APPDIR/usr/venv/bin/pip" install setuptools wheel build installer termcolor

# Step 5: Build wheel and install into venv
"$APPDIR/usr/venv/bin/python" -m build --wheel --no-isolation
"$APPDIR/usr/venv/bin/python" -m installer --destdir="$APPDIR/usr" dist/*.whl

# Step 6: Install wxPython manually
WX_WHL="wxpython-4.2.3-cp312-cp312-linux_x86_64.whl"
wget -O "$WX_WHL" "https://extras.wxpython.org/wxPython4/extras/linux/gtk3/ubuntu-24.04/$WX_WHL"
"$APPDIR/usr/venv/bin/python" -m installer --destdir="$APPDIR/usr" "$WX_WHL"

deactivate

# Step 7: Copy desktop file manually
DESKTOP_SRC="$WORKDIR/$PKGNAME-$PKGVERS/miscellaneous/WoeUSB-ng.desktop"
if [ ! -f "$DESKTOP_SRC" ]; then
    echo "Error: Desktop file missing at $DESKTOP_SRC"
    exit 1
fi
mkdir -p "$APPDIR/usr/share/applications"
cp "$DESKTOP_SRC" "$APPDIR/usr/share/applications/"
chmod 644 "$APPDIR/usr/share/applications/WoeUSB-ng.desktop"

# Step 8: Copy polkit policy
POLICY_SRC="$WORKDIR/com.github.woeusb.woeusb-ng.policy"
mkdir -p "$APPDIR/usr/share/polkit-1/actions"
cp "$POLICY_SRC" "$APPDIR/usr/share/polkit-1/actions/"

# Step 9: Create AppRun launcher
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="$HERE/usr/venv/bin:$PATH"
export PYTHONPATH="$HERE/usr/lib/python3.12/site-packages:$PYTHONPATH"
exec "$HERE/usr/venv/bin/woeusb" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Step 10: Download AppImageTool and build AppImage
cd "$WORKDIR"
wget -O appimagetool-x86_64.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
./appimagetool-x86_64.AppImage "$APPDIR" "$WORKDIR/$APPIMAGE_NAME"
