#!/bin/bash
#
# Builds AtomicBreak and packages it as an .ipa.
#
# Requires macOS with Xcode — iOS apps cannot be built anywhere else.
#
#   ./Scripts/build-ipa.sh                 # unsigned .ipa, for AltStore/Sideloadly
#   ./Scripts/build-ipa.sh --signed        # signed via ExportOptions.plist
#
# The unsigned build is the one to use without a paid Apple Developer account:
# sideloading tools re-sign the payload with your own free Apple ID anyway.
set -euo pipefail

PROJECT="Atomic.xcodeproj"
SCHEME="Atomic"
CONFIGURATION="Release"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/Atomic.xcarchive"
EXPORT_OPTIONS="ExportOptions.plist"
SIGNED=0

for arg in "$@"; do
	case "$arg" in
		--signed) SIGNED=1 ;;
		*) echo "unknown option: $arg" >&2; exit 2 ;;
	esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
	echo "error: xcodebuild not found. An .ipa can only be produced on macOS with Xcode." >&2
	exit 1
fi

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

if [ "${SIGNED}" -eq 1 ]; then
	echo "==> Archiving (signed)"
	xcodebuild archive \
		-project "${PROJECT}" \
		-scheme "${SCHEME}" \
		-configuration "${CONFIGURATION}" \
		-destination 'generic/platform=iOS' \
		-archivePath "${ARCHIVE_PATH}"

	echo "==> Exporting .ipa"
	xcodebuild -exportArchive \
		-archivePath "${ARCHIVE_PATH}" \
		-exportOptionsPlist "${EXPORT_OPTIONS}" \
		-exportPath "${BUILD_DIR}/ipa"

	IPA=$(find "${BUILD_DIR}/ipa" -name '*.ipa' -print -quit)
else
	echo "==> Archiving (unsigned)"
	xcodebuild archive \
		-project "${PROJECT}" \
		-scheme "${SCHEME}" \
		-configuration "${CONFIGURATION}" \
		-destination 'generic/platform=iOS' \
		-archivePath "${ARCHIVE_PATH}" \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGN_ENTITLEMENTS="" \
		AD_HOC_CODE_SIGNING_ALLOWED=YES

	# An .ipa is just a zip with the .app inside a Payload/ directory.
	echo "==> Packaging Payload/Atomic.app"
	rm -rf "${BUILD_DIR}/Payload"
	mkdir -p "${BUILD_DIR}/Payload"
	cp -R "${ARCHIVE_PATH}/Products/Applications/Atomic.app" "${BUILD_DIR}/Payload/"

	IPA="${PWD}/${BUILD_DIR}/Atomic-unsigned.ipa"
	(cd "${BUILD_DIR}" && zip -qry "${IPA}" Payload)
fi

if [ -z "${IPA:-}" ] || [ ! -f "${IPA}" ]; then
	echo "error: no .ipa was produced" >&2
	exit 1
fi

echo
echo "Built: ${IPA}"
ls -lh "${IPA}"
