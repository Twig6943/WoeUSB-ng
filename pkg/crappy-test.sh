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

# Step 3: Create Python virtualenv inside AppDir
python3 -m venv "$APPDIR/usr/venv"
source "$APPDIR/usr/venv/bin/activate"

# Upgrade pip and install dependencies
pip install --upgrade pip setuptools wheel build installer termcolor

#wxPython

# Step 4: Build wheel and install into AppDir
python -m build --wheel --no-isolation
wget https://extras.wxpython.org/wxPython4/extras/linux/gtk3/ubuntu-24.04/wxpython-4.2.3-cp312-cp312-linux_x86_64.whl
python -m installer --destdir="$APPDIR/usr" wxpython-4.2.3-cp312-cp312-linux_x86_64.whl
python -m installer --destdir="$APPDIR/usr" dist/*.whl

deactivate

# Step 5: Install desktop file and polkit policy
mkdir -p "$APPDIR/usr/share/applications"
cp miscellaneous/WoeUSB-ng.desktop "$APPDIR/usr/share/applications/"
chmod 755 "$APPDIR/usr/share/applications/WoeUSB-ng.desktop"

mkdir -p "$APPDIR/usr/share/polkit-1/actions"
cp ../com.github.woeusb.woeusb-ng.policy "$APPDIR/usr/share/polkit-1/actions/"

# Step 6: Create AppRun launcher
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="$HERE/usr/venv/bin:$PATH"
export PYTHONPATH="$HERE/usr/lib/python3.12/site-packages:$PYTHONPATH"
exec "$HERE/usr/venv/bin/woeusb" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Step 7: (Optional) copy icon
# mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
# cp path/to/icon.png "$APPDIR/usr/share/icons/hicolor/256x256/apps/WoeUSB-ng.png"

# Step 8: Download AppImageTool and build AppImage
cd "$WORKDIR"
wget -O appimagetool-x86_64.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
./appimagetool-x86_64.AppImage "$APPDIR" "$WORKDIR/$APPIMAGE_NAME"
