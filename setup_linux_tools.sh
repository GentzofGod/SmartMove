#!/usr/bin/env bash
# ==============================================================================
# SmartMove — Complete Linux Android & Java Toolchain Installer
# ==============================================================================
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}   SmartMove: Installing Android & Java Toolchain   ${NC}"
echo -e "${BLUE}====================================================${NC}"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
  echo -e "${RED}[ERROR] Detected architecture: $ARCH. This installer requires x86_64.${NC}"
  exit 1
fi

INSTALL_DIR="$HOME"
JAVA_DIR="$INSTALL_DIR/jdk-17"
ANDROID_DIR="$INSTALL_DIR/Android/Sdk"
FLUTTER_BIN="/data/workspace/flutter/bin"

# ------------------------------------------------------------------------------
# 1. Install Java JDK 17 (Adoptium Temurin)
# ------------------------------------------------------------------------------
if [ -d "$JAVA_DIR" ] && [ -f "$JAVA_DIR/bin/java" ]; then
  echo -e "${GREEN}[✓] Java 17 is already installed in:${NC} $JAVA_DIR"
else
  echo -e "\n${BLUE}--> [1/4] Downloading and installing Java JDK 17...${NC}"
  mkdir -p "$JAVA_DIR"
  TMP_JAVA="/tmp/temurin17.tar.gz"
  
  echo "Downloading Eclipse Temurin JDK 17..."
  curl -L "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse?project=jdk" -o "$TMP_JAVA"
  
  echo "Extracting Java to $JAVA_DIR..."
  tar -xzf "$TMP_JAVA" -C "$JAVA_DIR" --strip-components=1
  rm -f "$TMP_JAVA"
  echo -e "${GREEN}[✓] Java JDK 17 installed successfully!${NC}"
fi

export JAVA_HOME="$JAVA_DIR"
export PATH="$JAVA_HOME/bin:$PATH"
echo "Java version: $("$JAVA_DIR/bin/java" -version 2>&1 | head -n 1)"

# ------------------------------------------------------------------------------
# 2. Install Android Command-Line Tools
# ------------------------------------------------------------------------------
CMDLINE_DIR="$ANDROID_DIR/cmdline-tools/latest"
if [ -f "$CMDLINE_DIR/bin/sdkmanager" ]; then
  echo -e "${GREEN}[✓] Android Command-line Tools already installed in:${NC} $CMDLINE_DIR"
else
  echo -e "\n${BLUE}--> [2/4] Downloading Android SDK Command-line Tools...${NC}"
  mkdir -p "$ANDROID_DIR/cmdline-tools"
  TMP_CMDLINE="/tmp/cmdline-tools.zip"
  
  # Google official command-line tools zip
  curl -L "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o "$TMP_CMDLINE"
  
  echo "Extracting command-line tools..."
  unzip -q "$TMP_CMDLINE" -d "$ANDROID_DIR/cmdline-tools"
  rm -rf "$CMDLINE_DIR"
  mv "$ANDROID_DIR/cmdline-tools/cmdline-tools" "$CMDLINE_DIR"
  rm -f "$TMP_CMDLINE"
  echo -e "${GREEN}[✓] Android Command-line Tools installed successfully!${NC}"
fi

export ANDROID_HOME="$ANDROID_DIR"
export PATH="$PATH:$CMDLINE_DIR/bin:$ANDROID_DIR/platform-tools"

# ------------------------------------------------------------------------------
# 3. Install Android SDK Platforms, Build-Tools, and Platform-Tools
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}--> [3/4] Installing Android SDK Platform 34, Build-Tools 34, and Platform-Tools...${NC}"
yes | "$CMDLINE_DIR/bin/sdkmanager" --licenses > /dev/null 2>&1 || true

echo "Downloading platforms;android-34 and build-tools;34.0.0 (this may take 1-2 minutes)..."
"$CMDLINE_DIR/bin/sdkmanager" \
  "platform-tools" \
  "platforms;android-34" \
  "build-tools;34.0.0"

echo "Accepting any remaining licenses..."
yes | "$CMDLINE_DIR/bin/sdkmanager" --licenses > /dev/null 2>&1 || true

echo -e "${GREEN}[✓] Android SDK components installed successfully!${NC}"

# ------------------------------------------------------------------------------
# 4. Configure Flutter & Persist Environment Variables
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}--> [4/4] Configuring Flutter environment...${NC}"
if [ -d "$FLUTTER_BIN" ]; then
  export PATH="$FLUTTER_BIN:$PATH"
fi

# Configure Flutter to recognize the new Android SDK
flutter config --android-sdk "$ANDROID_HOME" > /dev/null 2>&1 || true

# Append permanently to ~/.bashrc if not already present
BASHRC="$HOME/.bashrc"
if ! grep -q "JAVA_HOME.*jdk-17" "$BASHRC" 2>/dev/null; then
  cat <<EOT >> "$BASHRC"

# SmartMove Android Development Environment
export JAVA_HOME="$JAVA_DIR"
export ANDROID_HOME="$ANDROID_DIR"
export PATH="\$JAVA_HOME/bin:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:/data/workspace/flutter/bin:\$PATH"
EOT
  echo -e "${GREEN}[✓] Appended environment variables to $BASHRC${NC}"
fi

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}       Installation Completed Successfully!         ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "You can now run:"
echo -e "  ${BLUE}./build_apk.sh${NC}"
echo -e "or:"
echo -e "  ${BLUE}flutter build apk --release --split-per-abi${NC}\n"

flutter doctor
