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

# Step 2: Create a virtual environment for build tools
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip

# Install installer before using it
pip install installer

# Step 4: Install wxPython manually into AppDir/usr
wget -O "wxpython-4.2.3-cp312-cp312-linux_x86_64.whl" \
"https://extras.wxpython.org/wxPython4/extras/linux/gtk3/ubuntu-24.04/wxpython-4.2.3-cp312-cp312-linux_x86_64.whl"
python3 -m installer --prefix="../AppDir/usr" "wxpython-4.2.3-cp312-cp312-linux_x86_64.whl"

# Install remaining Python build tools
pip install setuptools wheel build termcolor wxpython

# Step 3: Build wheel and install into AppDir/usr
python3 -m build --wheel --no-isolation
python3 -m installer --prefix="../AppDir/usr" dist/*.whl

# Step 3b: Copy data and locale directories manually
cp -r src/WoeUSB/data ../AppDir/usr/lib/python3.12/site-packages/WoeUSB/
cp -r src/WoeUSB/locale ../AppDir/usr/lib/python3.12/site-packages/WoeUSB/

# Done with build tools, deactivate venv
deactivate

# Step 5: Copy desktop file (ensure valid location for AppImage)
if [ ! -f "miscellaneous/WoeUSB-ng.desktop" ]; then
    echo "Error: Desktop file missing at miscellaneous/WoeUSB-ng.desktop"
    exit 1
fi
mkdir -p "../AppDir/usr/share/applications"
cp "miscellaneous/WoeUSB-ng.desktop" "../AppDir/"
cp "miscellaneous/WoeUSB-ng.desktop" "../AppDir/usr/share/applications/"
chmod 644 "../AppDir/WoeUSB-ng.desktop"
chmod 644 "../AppDir/usr/share/applications/WoeUSB-ng.desktop"

# Step 6: Copy logo
if [ ! -f "miscellaneous/woeusb-logo.png" ]; then
    echo "Error: logo missing at miscellaneous/woeusb-logo.png"
    exit 1
fi
cp "miscellaneous/woeusb-logo.png" "../AppDir/"

# Step 7: Copy polkit policy
mkdir -p "../AppDir/usr/share/polkit-1/actions"
cp "miscellaneous/com.github.woeusb.woeusb-ng.policy" "../AppDir/usr/share/polkit-1/actions/"

# Step 8: Create AppRun launcher
cat > "../AppDir/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PYTHONPATH="$HERE/usr/lib/python3.12/site-packages:$PYTHONPATH"
exec python3 "$HERE/usr/bin/woeusbgui" "$@"
EOF
chmod +x "../AppDir/AppRun"

# Step 9: Download AppImageTool and build AppImage
cd ..
wget -O "appimagetool-x86_64.AppImage" \
"https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
chmod +x "appimagetool-x86_64.AppImage"
./appimagetool-x86_64.AppImage "AppDir" "WoeUSB-ng-x86_64.AppImage"
