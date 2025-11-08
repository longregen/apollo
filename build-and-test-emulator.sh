#!/bin/bash
# Apollo Build and Emulator Test Script
# This script builds the Apollo app and tests it on an Android emulator

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration
EMULATOR_NAME="Apollo_Test_AVD"
SCREENSHOT_DIR="./screenshots"
SCREENSHOT_FILE="${SCREENSHOT_DIR}/apollo_screenshot_$(date +%Y%m%d_%H%M%S).png"
BUILD_FLAVOR="local"  # Options: local, regtest, prod, dogfood
BUILD_TYPE="debug"     # Options: debug, release, minified
WAIT_FOR_BOOT=120      # seconds to wait for emulator boot

# Check if we're in the apollo directory
if [ ! -f "build.gradle" ] || [ ! -d "android/apolloui" ]; then
    log_error "This script must be run from the apollo project root directory"
    exit 1
fi

# Check required environment variables
if [ -z "$ANDROID_SDK_ROOT" ] && [ -z "$ANDROID_HOME" ]; then
    log_error "ANDROID_SDK_ROOT or ANDROID_HOME not set. Did you run setup-dev-environment.sh?"
    exit 1
fi

if [ -z "$ANDROID_NDK_HOME" ]; then
    log_error "ANDROID_NDK_HOME not set. Did you run setup-dev-environment.sh?"
    exit 1
fi

# Create screenshots directory
mkdir -p "${SCREENSHOT_DIR}"

log_info "=========================================="
log_info "Apollo Build and Emulator Test"
log_info "=========================================="
log_info "Build Flavor: ${BUILD_FLAVOR}"
log_info "Build Type: ${BUILD_TYPE}"
log_info ""

# Step 1: Check Docker
log_step "Step 1/8: Checking Docker"
if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker daemon."
    log_info "Try: sudo systemctl start docker"
    exit 1
fi
log_info "Docker is running"

# Step 2: Build native libraries
log_step "Step 2/8: Building native libraries (libwallet/librs)"
log_info "This may take a while on first run..."
if [ -x "libwallet/librs/makelibs.sh" ]; then
    cd libwallet/librs
    ./makelibs.sh
    cd ../..
    log_info "Native libraries built successfully"
else
    log_warn "libwallet/librs/makelibs.sh not found or not executable, skipping..."
fi

# Step 3: Bootstrap gomobile
log_step "Step 3/8: Bootstrapping gomobile"
if [ -x "tools/bootstrap-gomobile.sh" ]; then
    ./tools/bootstrap-gomobile.sh
    log_info "Gomobile bootstrapped successfully"
else
    log_warn "tools/bootstrap-gomobile.sh not found or not executable, skipping..."
fi

# Step 4: Build libwallet for Android
log_step "Step 4/8: Building libwallet for Android"
if [ -x "tools/libwallet-android.sh" ]; then
    ./tools/libwallet-android.sh
    log_info "Libwallet for Android built successfully"
else
    log_warn "tools/libwallet-android.sh not found or not executable, skipping..."
fi

# Step 5: Build Apollo APK
log_step "Step 5/8: Building Apollo APK"
log_info "Running: ./gradlew :android:apolloui:assemble${BUILD_FLAVOR^}${BUILD_TYPE^}"

# Use installed gradle instead of wrapper if wrapper fails
if ./gradlew :android:apolloui:assemble${BUILD_FLAVOR^}${BUILD_TYPE^}; then
    log_info "APK built successfully using gradlew"
else
    log_warn "gradlew failed, trying with system Gradle..."
    gradle :android:apolloui:assemble${BUILD_FLAVOR^}${BUILD_TYPE^}
fi

# Find the generated APK
APK_PATH=$(find android/apolloui/build/outputs/apk -name "*.apk" | head -1)
if [ -z "$APK_PATH" ]; then
    log_error "No APK found after build!"
    exit 1
fi
log_info "APK found at: ${APK_PATH}"

# Step 6: Start Android Emulator
log_step "Step 6/8: Starting Android Emulator"

# Check if emulator is already running
if adb devices | grep -q "emulator"; then
    log_info "Emulator is already running"
else
    log_info "Starting emulator ${EMULATOR_NAME}..."

    # Start emulator in background
    # Use -no-snapshot-load to ensure clean boot
    # Use -no-audio to avoid audio issues in headless environments
    emulator -avd "${EMULATOR_NAME}" \
        -no-snapshot-load \
        -no-audio \
        -gpu swiftshader_indirect \
        -no-boot-anim \
        -camera-back none \
        -camera-front none \
        > /tmp/emulator.log 2>&1 &

    EMULATOR_PID=$!
    log_info "Emulator starting with PID ${EMULATOR_PID}"

    # Wait for emulator to boot
    log_info "Waiting for emulator to boot (timeout: ${WAIT_FOR_BOOT}s)..."
    timeout ${WAIT_FOR_BOOT} adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done'

    if [ $? -eq 0 ]; then
        log_info "Emulator booted successfully!"
    else
        log_error "Emulator boot timed out"
        log_info "Check emulator logs at: /tmp/emulator.log"
        exit 1
    fi

    # Give it a few more seconds to settle
    sleep 5
fi

# Get device serial
DEVICE_SERIAL=$(adb devices | grep "emulator" | awk '{print $1}' | head -1)
log_info "Using device: ${DEVICE_SERIAL}"

# Step 7: Install and Launch APK
log_step "Step 7/8: Installing and launching APK on emulator"
log_info "Installing APK..."
adb -s "${DEVICE_SERIAL}" install -r "${APK_PATH}"

# Get the package name and main activity
PACKAGE_NAME="io.muun.apollo"
if [[ "${BUILD_FLAVOR}" == "local" || "${BUILD_FLAVOR}" == "regtest" ]]; then
    PACKAGE_NAME="${PACKAGE_NAME}.${BUILD_FLAVOR}"
fi

log_info "Launching app (${PACKAGE_NAME})..."

# Launch the app
adb -s "${DEVICE_SERIAL}" shell am start -n "${PACKAGE_NAME}/${PACKAGE_NAME}.presentation.ui.launcher.LauncherActivity"

# Wait for app to start
log_info "Waiting for app to start..."
sleep 10

# Step 8: Take Screenshot
log_step "Step 8/8: Taking screenshot"
log_info "Capturing screenshot..."
adb -s "${DEVICE_SERIAL}" exec-out screencap -p > "${SCREENSHOT_FILE}"

if [ -f "${SCREENSHOT_FILE}" ]; then
    FILESIZE=$(stat -f%z "${SCREENSHOT_FILE}" 2>/dev/null || stat -c%s "${SCREENSHOT_FILE}" 2>/dev/null)
    if [ "$FILESIZE" -gt 1000 ]; then
        log_info "Screenshot saved successfully: ${SCREENSHOT_FILE}"
        log_info "File size: ${FILESIZE} bytes"
    else
        log_error "Screenshot file is too small, may be corrupted"
        exit 1
    fi
else
    log_error "Failed to save screenshot"
    exit 1
fi

# Show app info
log_info ""
log_info "=========================================="
log_info "App Information:"
log_info "=========================================="
adb -s "${DEVICE_SERIAL}" shell dumpsys package "${PACKAGE_NAME}" | grep -A 1 "versionName"

log_info ""
log_info "=========================================="
log_info "Build and Test Complete!"
log_info "=========================================="
log_info "APK: ${APK_PATH}"
log_info "Screenshot: ${SCREENSHOT_FILE}"
log_info "Device: ${DEVICE_SERIAL}"
log_info ""
log_info "Emulator is still running. To stop it:"
log_info "  adb -s ${DEVICE_SERIAL} emu kill"
log_info ""
log_info "To view logs:"
log_info "  adb -s ${DEVICE_SERIAL} logcat | grep Apollo"
log_info ""
