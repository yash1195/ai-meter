#!/bin/sh

set -eu

REPOSITORY="yash1195/ai-meter"
ASSET_NAME="AI-Meter.dmg"
EXPECTED_BUNDLE_ID="com.zeko.aimeter"
EXPECTED_TEAM_ID="L6AR4H8B39"
RELEASE_URL="https://github.com/${REPOSITORY}/releases/latest/download/${ASSET_NAME}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "AI Meter is a macOS app. This installer only runs on macOS." >&2
  exit 1
fi

for command_name in curl hdiutil codesign spctl; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command not found: ${command_name}" >&2
    exit 1
  fi
done

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/ai-meter-install.XXXXXX")"
dmg_path="${temporary_directory}/${ASSET_NAME}"
mount_path="${temporary_directory}/mounted"
mounted=0

cleanup() {
  if [ "${mounted}" -eq 1 ]; then
    hdiutil detach "${mount_path}" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "${temporary_directory}"
}
trap cleanup EXIT HUP INT TERM

echo "Downloading the latest AI Meter release…"
curl -fL --retry 3 --progress-bar "${RELEASE_URL}" -o "${dmg_path}"

mkdir -p "${mount_path}"
hdiutil attach -readonly -nobrowse -mountpoint "${mount_path}" "${dmg_path}" >/dev/null
mounted=1

source_app="${mount_path}/AI Meter.app"
if [ ! -d "${source_app}" ]; then
  echo "The installer image did not contain AI Meter.app." >&2
  exit 1
fi

actual_bundle_id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${source_app}/Contents/Info.plist")"
if [ "${actual_bundle_id}" != "${EXPECTED_BUNDLE_ID}" ]; then
  echo "Bundle ID verification failed. Expected ${EXPECTED_BUNDLE_ID}, found ${actual_bundle_id}." >&2
  exit 1
fi

if ! codesign --verify --deep --strict "${source_app}" 2>/dev/null; then
  echo "The downloaded app failed Apple code-signature verification." >&2
  exit 1
fi

if ! spctl --assess --type execute "${source_app}" 2>/dev/null; then
  echo "The downloaded app was not accepted by macOS Gatekeeper." >&2
  exit 1
fi

signature_details="$(codesign -dv --verbose=4 "${source_app}" 2>&1)"
actual_team_id="$(printf "%s\n" "${signature_details}" | sed -n "s/^TeamIdentifier=//p" | head -n 1)"
if [ "${actual_team_id}" != "${EXPECTED_TEAM_ID}" ]; then
  echo "Developer signature verification failed. Expected team ${EXPECTED_TEAM_ID}, found ${actual_team_id:-none}." >&2
  exit 1
fi

applications_directory="/Applications"
destination_app="${applications_directory}/AI Meter.app"
staged_app="${applications_directory}/.AI Meter.installing.$$"
backup_app="${applications_directory}/.AI Meter.backup.$$"
legacy_app="${HOME}/Applications/AI Meter.app"
needs_admin=0

if [ ! -w "${applications_directory}" ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "Administrator permission is required to install AI Meter in /Applications." >&2
    exit 1
  fi
  needs_admin=1
  echo "Administrator permission is required to install AI Meter in /Applications."
  sudo -v
fi

run_install_command() {
  if [ "${needs_admin}" -eq 1 ]; then
    sudo "$@"
  else
    "$@"
  fi
}

if [ -d "${destination_app}" ]; then
  existing_bundle_id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${destination_app}/Contents/Info.plist" 2>/dev/null || true)"
  if [ "${existing_bundle_id}" != "${EXPECTED_BUNDLE_ID}" ]; then
    echo "Refusing to replace ${destination_app}: its bundle ID is not ${EXPECTED_BUNDLE_ID}." >&2
    exit 1
  fi
fi

echo "Installing AI Meter in ${applications_directory}…"
run_install_command rm -rf "${staged_app}" "${backup_app}"
run_install_command cp -R "${source_app}" "${staged_app}"
if ! codesign --verify --deep --strict "${staged_app}" 2>/dev/null; then
  run_install_command rm -rf "${staged_app}"
  echo "The staged app failed code-signature verification." >&2
  exit 1
fi

if [ -d "${destination_app}" ]; then
  run_install_command mv "${destination_app}" "${backup_app}"
fi

if run_install_command mv "${staged_app}" "${destination_app}"; then
  run_install_command rm -rf "${backup_app}"
else
  run_install_command rm -rf "${staged_app}"
  if [ -d "${backup_app}" ]; then
    run_install_command mv "${backup_app}" "${destination_app}"
  fi
  echo "AI Meter could not be installed." >&2
  exit 1
fi

echo "AI Meter installed successfully."
if [ -d "${legacy_app}" ]; then
  echo "Note: an older copy may remain at ${legacy_app}. You can remove it after confirming the new app works."
fi
open "${destination_app}"
