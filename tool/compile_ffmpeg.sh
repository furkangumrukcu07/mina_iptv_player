#!/bin/bash
set -e

# ==============================================================================
# MINA IPTV - Better Player FFmpeg Decoder AAR Compilation Script (macOS)
# ==============================================================================

# Target directory in the local better_player_plus package
TARGET_DIR="/Users/macbook/Desktop/soncalısan/joy_tv/mina_iptv_player/packages/better_player_plus/android/third_party/decoder_ffmpeg"
TEMP_DIR="/tmp/media3_ffmpeg_build"
MEDIA3_VERSION="1.10.1"
NDK_VERSION="28.2.13676358"
NDK_PATH="/Users/macbook/Library/Android/sdk/ndk/$NDK_VERSION"
HOST_PLATFORM="darwin-x86_64"
ANDROID_ABI=21

echo "=== starting FFmpeg AAR compilation process ==="
echo "Target directory: $TARGET_DIR"
echo "NDK path: $NDK_PATH"
echo "Media3 version: $MEDIA3_VERSION"

# Ensure NDK exists
if [ ! -d "$NDK_PATH" ]; then
    echo "Error: Android NDK version $NDK_VERSION not found at $NDK_PATH."
    echo "Please check available versions under ~/Library/Android/sdk/ndk/ and edit this script."
    exit 1
fi

# Clean previous temp directory
if [ -d "$TEMP_DIR" ]; then
    echo "Cleaning old temp directory..."
    rm -rf "$TEMP_DIR"
fi

mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo "Cloning androidx/media repository..."
git clone --depth 1 --branch "release" https://github.com/androidx/media.git .

# Attempt to check out the exact tag matching media3Version
echo "Checking out version v$MEDIA3_VERSION..."
git fetch --tags
# Try different tag formats
if git checkout "tags/v$MEDIA3_VERSION" 2>/dev/null; then
    echo "Successfully checked out tag v$MEDIA3_VERSION"
elif git checkout "tags/release-$MEDIA3_VERSION" 2>/dev/null; then
    echo "Successfully checked out tag release-$MEDIA3_VERSION"
elif git checkout "tags/$MEDIA3_VERSION" 2>/dev/null; then
    echo "Successfully checked out tag $MEDIA3_VERSION"
else
    echo "Warning: Tag matching $MEDIA3_VERSION not found. Continuing with the default branch..."
fi

# Path to JNI directory inside decoder_ffmpeg
FFMPEG_MODULE_PATH="$TEMP_DIR/libraries/decoder_ffmpeg/src/main"
cd "$FFMPEG_MODULE_PATH/jni"

echo "Cloning FFmpeg source code (branch release/6.0)..."
if [ -d "ffmpeg" ]; then
    rm -rf ffmpeg
fi
git clone git://source.ffmpeg.org/ffmpeg --branch=release/6.0 --depth=1 ffmpeg

# Edit build_ffmpeg.sh to enable target audio decoders
echo "Configuring decoders in build_ffmpeg.sh..."
# Customize decoders (AC3, EAC3, DTS, OPUS, VORBIS, FLAC, AAC, MP3)
sed -i '' 's/ENABLED_DECODERS=(.*)/ENABLED_DECODERS=(ac3 eac3 dts opus vorbis flac aac mp3)/g' build_ffmpeg.sh || \
sed -i 's/ENABLED_DECODERS=(.*)/ENABLED_DECODERS=(ac3 eac3 dts opus vorbis flac aac mp3)/g' build_ffmpeg.sh

echo "Building native FFmpeg binaries via build_ffmpeg.sh..."
# Run the Media3 build script
# Disable building for x86 and x86_64 to speed up compile and bypass yasm requirement
export ENABLED_ABIS="armeabi-v7a arm64-v8a"
./build_ffmpeg.sh "$FFMPEG_MODULE_PATH" "$NDK_PATH" "$HOST_PLATFORM" "$ANDROID_ABI"

echo "Native compilation completed! Packaging the AAR..."
cd "$TEMP_DIR"

# Run Gradle build to assemble the AAR
./gradlew :lib-decoder-ffmpeg:assembleRelease

echo "Locating the generated AAR file..."
AAR_SOURCE=""
CANDIDATES=(
    "$TEMP_DIR/lib-decoder-ffmpeg/build/outputs/aar/decoder_ffmpeg-release.aar"
    "$TEMP_DIR/lib-decoder-ffmpeg/build/outputs/aar/lib-decoder-ffmpeg-release.aar"
    "$TEMP_DIR/lib-decoder-ffmpeg/build/outputs/aar/libraries-decoder_ffmpeg-release.aar"
    "$TEMP_DIR/libraries/decoder_ffmpeg/build/outputs/aar/decoder_ffmpeg-release.aar"
    "$TEMP_DIR/libraries/decoder_ffmpeg/build/outputs/aar/lib-decoder-ffmpeg-release.aar"
)


for path in "${CANDIDATES[@]}"; do
    if [ -f "$path" ]; then
        AAR_SOURCE="$path"
        break
    fi
done

if [ -n "$AAR_SOURCE" ]; then
    echo "Found AAR at: $AAR_SOURCE"
    mkdir -p "$TARGET_DIR"
    cp "$AAR_SOURCE" "$TARGET_DIR/decoder-ffmpeg-release.aar"
    echo "=== SUCCESS: FFmpeg AAR successfully compiled and copied to $TARGET_DIR ==="
else
    echo "Error: Could not find compiled AAR in output directories."
    exit 1
fi
