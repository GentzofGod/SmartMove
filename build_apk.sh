#!/usr/bin/env bash
# ==============================================================================
# SmartMove — Linux Direct APK Builder
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}       SmartMove — Linux Direct APK Builder        ${NC}"
echo -e "${BLUE}====================================================${NC}"

# Explicitly wire up installed toolchain
export JAVA_HOME="/data/home/jdk-17"
export ANDROID_HOME="/data/home/Android/Sdk"
export ANDROID_SDK_ROOT="/data/home/Android/Sdk"
export PATH="/data/home/.local/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:/data/workspace/flutter/bin:$PATH"

echo -e "${GREEN}[✓] Java:${NC} $($JAVA_HOME/bin/java -version 2>&1 | head -n 1)"
echo -e "${GREEN}[✓] Android SDK:${NC} $ANDROID_HOME"
echo -e "${GREEN}[✓] Flutter:${NC} $(/data/workspace/flutter/bin/flutter --version | head -n 1)"

# Ensure android/local.properties has both sdk.dir and flutter.sdk
mkdir -p android
cat <<EOF > android/local.properties
sdk.dir=/data/home/Android/Sdk
flutter.sdk=/data/workspace/flutter
EOF

# Ensure Flutter config knows the Android SDK & JDK
/data/workspace/flutter/bin/flutter config --android-sdk "$ANDROID_HOME" --jdk-dir "$JAVA_HOME" > /dev/null 2>&1 || true

# Ensure .env exists
if [ ! -f ".env" ]; then
  if [ -f ".env.example" ]; then
    cp .env.example .env
  fi
fi

# Wire up dart-define arguments from .env
DART_DEFINE_ARGS=()
if [ -f ".env" ]; then
  echo -e "\n${GREEN}[✓] Found .env file, configuring Dart Define environment variables:${NC}"
  DART_DEFINE_ARGS+=("--dart-define-from-file=.env")
  while IFS='=' read -r key value || [ -n "$key" ]; do
    clean_key=$(echo "$key" | tr -d ' \r\n\t')
    if [[ ! "$clean_key" =~ ^#.* ]] && [ -n "$clean_key" ]; then
      clean_val=$(echo "$value" | tr -d '\r\n')
      DART_DEFINE_ARGS+=("--dart-define=$clean_key=$clean_val")
      # Mask sensitive keys for output
      masked_val="${clean_val:0:6}...${clean_val: -4}"
      echo -e "    * Injected: ${clean_key}=${masked_val}"
    fi
  done < .env
fi

# Ensure gradlew is executable
if [ -f "android/gradlew" ]; then
  chmod +x android/gradlew
fi

# Fetch dependencies
echo -e "\n${BLUE}--> Fetching dependencies (flutter pub get)...${NC}"
/data/workspace/flutter/bin/flutter pub get

# Build APK
MODE="${1:---split}"
echo -e "\n${BLUE}--> Starting build (${MODE}) with Dart Define environment...${NC}"
echo -e "${YELLOW}[Note] Building and assembling Gradle tasks...${NC}"

case "$MODE" in
  --universal)
    echo "Building universal release APK..."
    /data/workspace/flutter/bin/flutter build apk --release "${DART_DEFINE_ARGS[@]}"
    ;;
  --debug)
    echo "Building debug APK..."
    /data/workspace/flutter/bin/flutter build apk --debug "${DART_DEFINE_ARGS[@]}"
    ;;
  --split|*)
    echo "Building split APKs per ABI (arm64-v8a, armeabi-v7a, x86_64)..."
    /data/workspace/flutter/bin/flutter build apk --release --split-per-abi "${DART_DEFINE_ARGS[@]}"
    ;;
esac

OUTPUT_DIR="build/app/outputs/flutter-apk"

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}             Build Finished!                       ${NC}"
echo -e "${GREEN}====================================================${NC}"

if [ -d "$OUTPUT_DIR" ]; then
  echo -e "Generated APK(s):"
  ls -lh "$OUTPUT_DIR"/*.apk 2>/dev/null || echo "No APK files found."
fi
