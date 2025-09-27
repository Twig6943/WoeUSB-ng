#!/bin/bash
set -e

rm -rf "./WoeUSB-ng-build"
mkdir -p "./WoeUSB-ng-build/AppDir/usr"

cd "./WoeUSB-ng-build"
git clone https://github.com/Twig6943/WoeUSB-ng.git
cd "WoeUSB-ng"
wget -O "pr79.patch" "https://gitlab.com/chaotic-aur/pkgbuilds/-/raw/main/woeusb-ng/pr79.patch"
patch --forward --strip=1 < pr79.patch || true

# Python venv for build tools
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install setuptools wheel build installer termcolor

# Build WoeUSB wheel and install into AppDir
python3 -m build --wheel --no-isolation
python3 -m installer --prefix="../AppDir/usr" dist/*.whl

# Install wxPython directly into AppDir/usr/lib/python3.12/site-packages
WX_WHL_URL="https://extras.wxpython.org/wxPython4/extras/linux/gtk3/ubuntu-24.04/wxpython-4.2.3-cp312-cp312-linux_x86_64.whl"
pip install --target="../AppDir/usr/lib/python3.12/site-packages" "$WX_WHL_URL"

deactivate

# Copy desktop, logo, polkit
mkdir -p "../AppDir/usr/share/applications" "../AppDir/usr/share/polkit-1/actions"
cp "miscellaneous/WoeUSB-ng.desktop" "../AppDir/"
cp "miscellaneous/WoeUSB-ng.desktop" "../AppDir/usr/share/applications/"
cp "miscellaneous/woeusb-logo.png" "../AppDir/"
cp "miscellaneous/com.github.woeusb.woeusb-ng.policy" "../AppDir/usr/share/polkit-1/actions/"

chmod 644 "../AppDir/WoeUSB-ng.desktop" "../AppDir/usr/share/applications/WoeUSB-ng.desktop"

# AppRun launcher
cat > "../AppDir/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PYTHONPATH="$HERE/usr/lib/python3.12/site-packages:$PYTHONPATH"
export LD_LIBRARY_PATH="$HERE/usr/lib/python3.12/site-packages/wx/lib:$LD_LIBRARY_PATH"
exec python3 "$HERE/usr/bin/woeusbgui" "$@"
EOF
chmod +x "../AppDir/AppRun"

# Build AppImage
cd ..
wget -O "appimagetool-x86_64.AppImage" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
chmod +x "appimagetool-x86_64.AppImage"
./appimagetool-x86_64.AppImage "AppDir" "WoeUSB-ng-x86_64.AppImage"
