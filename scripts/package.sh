#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/build.sh Release

app_path="build/Build/Products/Release/ChatHub.app"
dist_dir="dist"
staging_dir="$dist_dir/dmg-staging"
zip_path="$dist_dir/ChatHub-macOS.zip"
dmg_path="$dist_dir/ChatHub-macOS.dmg"

rm -rf "$dist_dir"
mkdir -p "$staging_dir"

ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"

cp -R "$app_path" "$staging_dir/ChatHub.app"
ln -s /Applications "$staging_dir/Applications"
hdiutil create -volname "ChatHub" -srcfolder "$staging_dir" -ov -format UDZO "$dmg_path" >/dev/null
rm -rf "$staging_dir"

echo "Packaged:"
echo "  DMG: $PWD/$dmg_path"
echo "  ZIP: $PWD/$zip_path"
shasum -a 256 "$dmg_path" "$zip_path"
