#!/bin/bash
# Apollo Android Development Environment Setup Script for Ubuntu 24.04
# This script sets up a complete development environment for building and testing the Apollo Android app

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Configuration
ANDROID_SDK_ROOT="${HOME}/Android/Sdk"
ANDROID_NDK_VERSION="27.2.12479018"
ANDROID_BUILD_TOOLS_VERSION="34.0.0"
ANDROID_PLATFORM_VERSION="34"
ANDROID_EMULATOR_API_LEVEL="34"
ANDROID_EMULATOR_ABI="x86_64"
ANDROID_EMULATOR_NAME="Apollo_Test_AVD"
CMDLINE_TOOLS_VERSION="11076708"

log_info "Starting Apollo Android Development Environment Setup"
log_info "This will install: Android SDK, NDK, Docker, and configure an Android emulator"

# Update system
log_info "Updating system packages..."
sudo apt-get update

# Install basic dependencies
log_info "Installing basic dependencies..."
sudo apt-get install -y \
    wget \
    curl \
    git \
    unzip \
    zip \
    openjdk-17-jdk \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release

# Install Docker
log_info "Installing Docker..."
if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository to Apt sources
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add current user to docker group
    sudo usermod -aG docker $USER
    log_warn "You may need to log out and back in for Docker group permissions to take effect"
else
    log_info "Docker already installed"
fi

# Start Docker service
log_info "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Install Android SDK Command Line Tools
log_info "Installing Android SDK Command Line Tools..."
mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools"

if [ ! -d "${ANDROID_SDK_ROOT}/cmdline-tools/latest" ]; then
    CMDLINE_TOOLS_ZIP="commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
    wget -q "https://dl.google.com/android/repository/${CMDLINE_TOOLS_ZIP}" -O /tmp/${CMDLINE_TOOLS_ZIP}
    unzip -q /tmp/${CMDLINE_TOOLS_ZIP} -d "${ANDROID_SDK_ROOT}/cmdline-tools"
    mv "${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools" "${ANDROID_SDK_ROOT}/cmdline-tools/latest"
    rm /tmp/${CMDLINE_TOOLS_ZIP}
    log_info "Android SDK Command Line Tools installed"
else
    log_info "Android SDK Command Line Tools already installed"
fi

# Set up environment variables
log_info "Setting up environment variables..."
cat >> ~/.bashrc << EOF

# Android SDK
export ANDROID_HOME="${ANDROID_SDK_ROOT}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT}"
export ANDROID_NDK_HOME="${ANDROID_SDK_ROOT}/ndk/${ANDROID_NDK_VERSION}"
export PATH=\$PATH:\${ANDROID_HOME}/cmdline-tools/latest/bin
export PATH=\$PATH:\${ANDROID_HOME}/platform-tools
export PATH=\$PATH:\${ANDROID_HOME}/emulator
export PATH=\$PATH:\${ANDROID_HOME}/tools
export PATH=\$PATH:\${ANDROID_HOME}/tools/bin

EOF

# Source the updated bashrc for current session
export ANDROID_HOME="${ANDROID_SDK_ROOT}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT}"
export PATH=$PATH:${ANDROID_HOME}/cmdline-tools/latest/bin
export PATH=$PATH:${ANDROID_HOME}/platform-tools
export PATH=$PATH:${ANDROID_HOME}/emulator
export PATH=$PATH:${ANDROID_HOME}/tools
export PATH=$PATH:${ANDROID_HOME}/tools/bin

# Accept Android SDK licenses
log_info "Accepting Android SDK licenses..."
yes | sdkmanager --licenses || true

# Install Android SDK components
log_info "Installing Android SDK components..."
sdkmanager --install \
    "platform-tools" \
    "platforms;android-${ANDROID_PLATFORM_VERSION}" \
    "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
    "ndk;${ANDROID_NDK_VERSION}" \
    "emulator" \
    "system-images;android-${ANDROID_EMULATOR_API_LEVEL};google_apis;${ANDROID_EMULATOR_ABI}"

# Set ANDROID_NDK_HOME after NDK installation
export ANDROID_NDK_HOME="${ANDROID_SDK_ROOT}/ndk/${ANDROID_NDK_VERSION}"

log_info "Android SDK components installed successfully"

# Install KVM for hardware acceleration (for emulator)
log_info "Installing KVM for Android Emulator hardware acceleration..."
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker

# Add user to kvm group
sudo usermod -aG kvm $USER

# Check if KVM is available
if kvm-ok &> /dev/null; then
    log_info "KVM is available and working"
else
    log_warn "KVM may not be available. Emulator will run in software mode (slower)"
fi

# Create Android Virtual Device (AVD)
log_info "Creating Android Virtual Device..."
if avdmanager list avd | grep -q "${ANDROID_EMULATOR_NAME}"; then
    log_info "AVD ${ANDROID_EMULATOR_NAME} already exists"
else
    echo "no" | avdmanager create avd \
        -n "${ANDROID_EMULATOR_NAME}" \
        -k "system-images;android-${ANDROID_EMULATOR_API_LEVEL};google_apis;${ANDROID_EMULATOR_ABI}" \
        -d "pixel_5" \
        --force

    log_info "AVD ${ANDROID_EMULATOR_NAME} created successfully"
fi

# Install scrcpy for screenshots (alternative to adb screencap)
log_info "Installing scrcpy for screen capture..."
sudo apt-get install -y scrcpy

log_info "=========================================="
log_info "Setup Complete!"
log_info "=========================================="
log_info ""
log_info "Environment variables have been added to ~/.bashrc"
log_info "Please run: source ~/.bashrc"
log_info ""
log_info "Or log out and log back in for all changes to take effect."
log_info ""
log_info "To verify the setup:"
log_info "  1. Check Android SDK: sdkmanager --list_installed"
log_info "  2. Check Docker: docker --version"
log_info "  3. List AVDs: avdmanager list avd"
log_info ""
log_info "Next steps to build and test Apollo:"
log_info "  1. source ~/.bashrc"
log_info "  2. cd /path/to/apollo"
log_info "  3. Run: ./build-and-test-emulator.sh"
log_info ""
