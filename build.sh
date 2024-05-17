#!/bin/bash

# 1. Script argument validation
# Print Usage if input validation fails
USAGE="Usage: $(basename "$0") <plugin> [branch] [version]"
ARCHIVE_DIR="./archive"
SOURCE_DIR="./source"
PLUGIN_DIR="./plugin"

PLUGIN="$1"  # <plugin>
BRANCH="$2"  # current repo [branch]
VERSION="$3" # [version] of current build (date format 'YYYYmmdd')

# Validate argument length
if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  echo "$USAGE"
  exit 1
fi

# Verify <plugin> name has a respective .plg file
PLUGIN_FILE="$PLUGIN_DIR/$PLUGIN"
if [[ $PLUGIN_FILE != *.plg ]]; then
  echo "$USAGE"
  exit 1
fi

# if [branch] is not passed, assign 'main'
if [ -z "$BRANCH" ]; then
  BRANCH="main"
fi

# if a custom [versopn] is not passed, use today's date
if [ -z "$VERSION" ]; then
  VERSION=$(date +%Y%m%d)
fi

# If macOS, use GNU versions of 'tar' and 'sed'
# TODO: Add Required GNU Binaries to README if Mac
if [ "$(uname)" == "Darwin" ]; then
  PREFIX="g"
else
  PREFIX=""
fi

set -e

SED_BIN=${PREFIX}sed
TAR_BIN=${PREFIX}tar

# Extract name from plugin file - source dir must match
NAME=$("$SED_BIN" -n 's/<!ENTITY[ ]\+name[ ]\+"\(.*\)">/\1/p' "$PLUGIN_FILE")
if [ -z "$NAME" ]; then
  echo "Error: Pattern not found in the file. Found '$NAME'"
  exit 1
fi

# Archive file to be uncompressed under emhttp plugin directory upon CA Plugin Install
FILE_NAME="$NAME-$VERSION.txz"
PACKAGE_DIR="$SOURCE_DIR/$NAME"

# Validate source -- plugin files to be installed within unRAID's webGui
if [ -d "$PACKAGE_DIR" ]; then
  if [ -z "$(ls -A "$PACKAGE_DIR")" ]; then
    echo "Folder exists but is empty."
    exit 1
  fi
else
  echo "Folder does not exist."
  exit 1
fi

echo "================================================"
echo "           Building UnRaid plugin package"
echo "================================================"
echo "Plugin: ${PLUGIN_FILE}"
echo "Name: ${NAME}"
echo "Source: ${PACKAGE_DIR}"
echo "Archive: ${ARCHIVE_DIR}"
echo "================================================"

# Package build output as tar archive for release
mkdir -p "$ARCHIVE_DIR"
FILE="$(realpath ${ARCHIVE_DIR})/$FILE_NAME"

pushd "$PACKAGE_DIR"
echo "Setting file permissions..."
find usr -type f -exec dos2unix {} \;
chmod -R 755 usr/

echo "Creating archive..."
"$TAR_BIN" -cJf "$FILE" --owner=0 --group=0 usr/
popd

echo "Verifying package"
if [ -f "$FILE" ]; then
  MD5_HASH=$(md5sum "$FILE" | cut -f 1 -d " ")

  if [ -z "$MD5_HASH" ]; then
    echo "Could not verify archive"
    exit 1
  fi

  echo "Packaged successfully: ${MD5_HASH}"

  echo "Updating plugin info..."
  "$SED_BIN" -i.bak '/'"<!ENTITY md5"'/s/.*/'"<!ENTITY md5 \"${MD5_HASH}\">"'/' "${PLUGIN_FILE}"
  "$SED_BIN" -i.bak '/'"<!ENTITY version"'/s/.*/'"<!ENTITY version \"${VERSION}\">"'/' "${PLUGIN_FILE}"
  "$SED_BIN" -i.bak '/'"<!ENTITY branch"'/s/.*/'"<!ENTITY branch \"${BRANCH}\">"'/' "${PLUGIN_FILE}"
else
  echo "Failed to build package!"
fi

echo "Done."
