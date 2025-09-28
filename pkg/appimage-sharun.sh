#!/bin/bash
set -e

# Remove any previous build
rm -rf "./WoeUSB-ng-build"
mkdir -p "./WoeUSB-ng-build/AppDir/usr/bin"

# Step 1: Clone repository and apply patch
cd "./WoeUSB-ng-build"
git clone https://github.com/Twig6943/WoeUSB-ng.git
cd "WoeUSB-ng"
wget -O "pr79.patch" "https://gitlab.com/chaotic-aur/pkgbuilds/-/raw/main/woeusb-ng/pr79.patch"
patch --forward --strip=1 < pr79.patch || true

# Step 2: Create a virtual environment for build tools
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip installer setuptools wheel build termcolor

# Step 3: Build wheel and install into AppDir/usr
python3 -m build --wheel --no-isolation
python3 -m installer --prefix="../AppDir/usr" dist/*.whl

# Step 3b: Ensure WoeUSB sources are copied (fix missing module issue)
PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
mkdir -p "../AppDir/usr/lib/python${PYVER}/site-packages/"
cp -r src/WoeUSB "../AppDir/usr/lib/python${PYVER}/site-packages/"

# Step 3c: Copy woeusbgui executable
mkdir -p "../AppDir/usr/bin"
cp src/woeusbgui "../AppDir/usr/bin/"
chmod +x "../AppDir/usr/bin/woeusbgui"

# Step 4: Copy data and locale directories
cp -r src/WoeUSB/data "../AppDir/usr/lib/python${PYVER}/site-packages/WoeUSB/"
cp -r src/WoeUSB/locale "../AppDir/usr/lib/python${PYVER}/site-packages/WoeUSB/"

# Done with build tools, deactivate venv
deactivate

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

# Step 8: Create AppRun launcher (dynamic PYVER)
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
