#!/bin/bash
USAGE="Usage: $(basename "$0") <plugin> [branch] [version]"

printUsageAndQuit() {
  echo "$USAGE"
  exit 1
}

validateFolderExistsAndNotEmpty() {
  if [ -d "./$1" ]; then
    if [ -z "$(ls -A "./$1")" ]; then
      echo "Folder exists but is empty."
      exit 1
    fi
  else
    echo "Folder does not exist."
    exit 1
  fi
}

# echo "fileWorkspaceFolder = ${fileWorkspaceFolder}"
# echo "relativeFile = ${relativeFile}"
# echo "relativeFileDirname = ${relativeFileDirname}"
# echo "fileBasename = ${fileBasename}"
# echo "fileBasenameNoExtension = ${fileBasenameNoExtension}"
# echo "fileDirname = ${fileDirname}"
# echo "leExtname = ${fileExtname}"
# echo "lineNumber = ${lineNumber}"
# echo "selectedText = ${selectedText}"
# echo "execPath = ${execPath}"
# echo "pathSeparator = ${pathSeparator}"

printf "\n\n1. Script argument validation"
# Print Usage if input validation fails
# USAGE="Usage: $(basename "$0") <plugin> [branch] [version]"

ARCHIVE_DIR="archive"
BUILD_DIR="build"
PLUGIN_DIR="plugin"
SOURCE_DIR="source"
# WS_HOME_PATH="${workspaceFolderBasename}"

PLUGIN="$1"  # <plugin>
BRANCH="$2"  # current repo [branch]
VERSION="$3" # [version] of current build (date format 'YYYYmmdd')

# Validate argument length
if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  # echo "$USAGE"
  # exit 1
  printUsageAndQuit
fi

# Verify <plugin> name has a respective .plg file
PLUGIN_FILE="$PLUGIN_DIR/$PLUGIN"
# echo "PWD = $PWD"
# echo "PLUGIN_FILE = $PLUGIN_FILE"
if [[ $PLUGIN_FILE != *.plg ]]; then
  printUsageAndQuit
fi

# if [branch] is not passed, assign 'main'
if [ -z "$BRANCH" ]; then
  BRANCH="main"
fi

# if [version] is not passed, use today's date
if [ -z "$VERSION" ]; then
  VERSION=$(date +%Y%m%d)
fi

printf "\n\n2. macOS systems must use GNU implementations of sed and tar to match commands across other systems."
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
# echo "0. PWD before extracting plugin name from .plg file = $PWD"

printf "\n\n3. Extract plugin name from .plg file"
# Extract name from plugin file - source dir must match
NAME=$("$SED_BIN" -n 's/<!ENTITY[ ]\+name[ ]\+"\(.*\)">/\1/p' "$PLUGIN_FILE")
if [ -z "$NAME" ]; then
  echo "Error: Pattern not found in the file. Found '$NAME'"
  exit 1
fi

PLUGIN_BUILD_DIR="$BUILD_DIR/$NAME"
printf "\n\n4. Create build directories...\n"
# Create 'build' directories
# mkdir -p "$WS_HOME_PATH/$BUILD_DIR"
printf "\t...Creating $PLUGIN_BUILD_DIR"
mkdir -pv $PLUGIN_BUILD_DIR

# if [[ -d $PLUGIN_BUILD_DIR ]]; then
#   echo "PLUGIN_BUILD_DIR is a directory located at $PLUGIN_BUILD_DIR"
# fi

# echo "g1. PWD = $PWD"

printf "\n\n5. Copy 'source/$NAME' emhttp directories to 'build'"
cd ./"$SOURCE_DIR"/"$NAME"
# echo "2. PWD = $PWD"
cp -R ./* ../../$PLUGIN_BUILD_DIR/
# echo "3. PWD = $PWD"

# pushd "./$PLUGIN_BUILD_DIR/"
# echo "4. PWD = $PWD"
cd "../../$PLUGIN_BUILD_DIR"
# echo "PWD = $PWD after cd'ing into $PLUGIN_BUILD_DIR"

printf "\n\n6. Setting any DOS-encoded files to Unix..."
# echo "After 6, PWD = $PWD"
find ./usr -type f -exec dos2unix -q {} \;

printf "\n\n7. Setting file permissions..."
# echo "After 7, PWD = $PWD"
chmod -R 755 ./usr/

cd ../../

# Validate source -- plugin files to be installed within unRAID's webGui
validateFolderExistsAndNotEmpty $PLUGIN_BUILD_DIR
# if [ -d "./$PLUGIN_BUILD_DIR" ]; then
#   if [ -z "$(ls -A "./$PLUGIN_BUILD_DIR")" ]; then
#     echo "Folder exists but is empty."
#     exit 1
#   fi
# else
#   echo "Folder does not exist."
#   exit 1
# fi

# cp -R usr/ $WS_HOME_PATH/$PLUGIN_BUILD_DIR

printf "\n\n8. Create archive dir and tar file for release storage"
result=${mkdir-p "$ARCHIVE_DIR"}
# Archive files to be uncompressed under emhttp plugin directory upon CA Plugin Install
VERSIONED_FILE_NAME="$NAME-$VERSION.txz"
ARCHIVE_FILE="$(realpath ${ARCHIVE_DIR})/$VERSIONED_FILE_NAME"
# echo "ARCHIVE_FILE = $ARCHIVE_FILE"

printf "\t...Creating archive. ${ARCHIVE_FILE}"
cd $PLUGIN_BUILD_DIR
"$TAR_BIN" -cJf "$ARCHIVE_FILE" --owner=0 --group=0 ./usr/
cd ../../
# popd

echo ""
echo "================================================"
echo "           Building UnRaid plugin package"
echo "================================================"
echo "Plugin File: ${PLUGIN_FILE}"
echo "Plugin Name: ${NAME}"
echo "Plugin Build: ${PLUGIN_BUILD_DIR}"
echo "Archive Dir: ${ARCHIVE_DIR}"
echo "Archive File: ${VERSIONED_FILE_NAME}"
echo "================================================"
echo ""

printf "\n\n9. Verifying archive...\n\n"
if [ -f "$ARCHIVE_FILE" ]; then
  MD5_HASH=$(md5sum "$ARCHIVE_FILE" | cut -f 1 -d " ")

  if [ -z "$MD5_HASH" ]; then
    echo "...[ERROR] Could not verify archive"
    exit 1
  fi

  printf "...Packaged successfully\n."
  printf "...Calculated MD5 Hash: ${MD5_HASH}"
fi

printf "\n\n10. Clean-up build artifacts.\n"
echo "PWD=$PWD"
printf "\t...Deleting build directory...\n"
rm -rf $BUILD_DIR

if [ -d $BUILD_DIR ]; then
  printf "\t...[WARN] Failed to delete $BUILD_DIR\n"
else
  printf "\t...[INFO] Successfully deleted $BUILD_DIR\n"
fi

printf "\n\nDone.\n\n"
