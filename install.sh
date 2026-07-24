#!/bin/sh

set -eu

REPOSITORY="yash1195/ai-meter"
ASSET_NAME="AI-Meter.zip"
EXPECTED_BUNDLE_ID="com.zeko.aimeter"
EXPECTED_TEAM_ID="L6AR4H8B39"
RELEASE_URL="https://github.com/${REPOSITORY}/releases/latest/download/${ASSET_NAME}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "AI Meter is a macOS app. This installer only runs on macOS." >&2
  exit 1
fi

for command_name in curl ditto codesign; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command not found: ${command_name}" >&2
    exit 1
  fi
done

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/ai-meter-install.XXXXXX")"
archive_path="${temporary_directory}/${ASSET_NAME}"
extracted_path="${temporary_directory}/extracted"

cleanup() {
  rm -rf "${temporary_directory}"
}
trap cleanup EXIT HUP INT TERM

echo "Downloading the latest AI Meter release…"
curl -fL --retry 3 --progress-bar "${RELEASE_URL}" -o "${archive_path}"

mkdir -p "${extracted_path}"
ditto -x -k "${archive_path}" "${extracted_path}"

source_app="${extracted_path}/AI Meter.app"
if [ ! -d "${source_app}" ]; then
  echo "The release archive did not contain AI Meter.app." >&2
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

signature_details="$(codesign -dv --verbose=4 "${source_app}" 2>&1)"
actual_team_id="$(printf "%s\n" "${signature_details}" | sed -n "s/^TeamIdentifier=//p" | head -n 1)"
if [ "${actual_team_id}" != "${EXPECTED_TEAM_ID}" ]; then
  echo "Developer signature verification failed. Expected team ${EXPECTED_TEAM_ID}, found ${actual_team_id:-none}." >&2
  exit 1
fi

applications_directory="${HOME}/Applications"
destination_app="${applications_directory}/AI Meter.app"
mkdir -p "${applications_directory}"

echo "Installing AI Meter in ${applications_directory}…"
ditto "${source_app}" "${destination_app}"

echo "AI Meter installed successfully."
open "${destination_app}"
