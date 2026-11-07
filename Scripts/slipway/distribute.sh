#!/usr/bin/env bash
# Archive, export and upload one platform's app to App Store Connect. The last
# step of `make release`; runnable alone to rebuild or re-upload the version +
# build currently in project.yml.
#
# Usage:
#   distribute.sh ios                 # archive → export → upload
#   distribute.sh macos --no-upload   # build the .pkg into dist/, skip the upload
#   distribute.sh ios --upload-only   # upload the .ipa already in dist/
#
# One-time setup:
#   • An App Store Connect API key (Users and Access → Integrations → App Store
#     Connect API, App Manager role). Put the .p8 at
#     ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8, and its Key ID +
#     Issuer ID in Scripts/.asc-config (gitignored):
#         ASC_KEY_ID=…
#         ASC_ISSUER_ID=…
# Signing is automatic (as in Xcode's Organizer); no cert/profile to install.
set -euo pipefail
. "$(dirname "$0")/release-lib.sh"

platform="${1:-}"
upload=1
build=1
shift || true
while [ $# -gt 0 ]; do
    case "$1" in
        --no-upload) upload=0 ;;
        --upload-only) build=0 ;;
        *) die "unknown argument '$1'" ;;
    esac
    shift
done
[ "$upload" -eq 1 ] || [ "$build" -eq 1 ] || die "--no-upload and --upload-only are mutually exclusive."

case "$platform" in
    ios) destination="generic/platform=iOS" ext="ipa" ;;
    macos) destination="generic/platform=macOS" ext="pkg" ;;
    *) die "usage: distribute.sh <ios|macos> [--no-upload|--upload-only]" ;;
esac
scheme="$(plat_scheme "$platform")"
out="dist/${platform}"
archive="${out}/${SLIPWAY_NAME}-${platform}.xcarchive"

if [ "$build" -eq 1 ]; then
    [ -d "$SLIPWAY_XCODEPROJ" ] || die "$SLIPWAY_XCODEPROJ missing — run make generate first."
    rm -rf "$out"
    mkdir -p "$out"

    # App Store export, signed automatically for the project's team. Written
    # here rather than kept per project: the team is the only thing that varies.
    team="$(read_unique DEVELOPMENT_TEAM)"
    options="${out}/ExportOptions.plist"
    cat >"$options" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>export</string>
    <key>teamID</key>
    <string>${team}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF

    say "Archiving ${scheme}…"
    xcodebuild archive \
        -project "$SLIPWAY_XCODEPROJ" \
        -scheme "$scheme" \
        -destination "$destination" \
        -archivePath "$archive" \
        -allowProvisioningUpdates

    say "Exporting (.${ext})…"
    xcodebuild -exportArchive \
        -archivePath "$archive" \
        -exportPath "$out" \
        -exportOptionsPlist "$options" \
        -allowProvisioningUpdates
fi

# The exported package is named after the product; find it.
pkg="$([ -d "$out" ] && /usr/bin/find "$out" -maxdepth 1 -name "*.${ext}" | head -1 || true)"
if [ -z "$pkg" ]; then
    [ "$build" -eq 0 ] && die "no .${ext} in $out to upload — run a build (make release-build) first."
    die "no .${ext} produced in $out"
fi
echo "  → $pkg"

if [ "$upload" -eq 0 ]; then
    echo "✓ Built $pkg (upload skipped)."
    exit 0
fi

config="Scripts/.asc-config"
[ -f "$config" ] || die "$config missing — put your App Store Connect API Key ID + Issuer ID in it (see this script's header)."
# shellcheck disable=SC1090
. "$config"
: "${ASC_KEY_ID:?set ASC_KEY_ID in $config}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID in $config}"

say "Uploading to App Store Connect…"
xcrun altool --upload-app \
    --type "$platform" \
    --file "$pkg" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

echo "✓ Uploaded ${platform} build to App Store Connect (processing takes a few minutes)."
