#!/bin/bash
# Apollo Quick Start - Complete Setup and Build in One Command
# This script automates the entire process from fresh Ubuntu 24.04 to running app with screenshot

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running on Ubuntu 24.04
if ! grep -q "24.04" /etc/os-release 2>/dev/null; then
    echo -e "${YELLOW}Warning: This script is designed for Ubuntu 24.04${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

log_info "=========================================="
log_info "Apollo Quick Start"
log_info "=========================================="
log_info "This script will:"
log_info "  1. Install all required dependencies"
log_info "  2. Set up Android SDK and NDK"
log_info "  3. Install and configure Docker"
log_info "  4. Create an Android emulator"
log_info "  5. Build the Apollo app"
log_info "  6. Run the app on the emulator"
log_info "  7. Take a screenshot"
log_info ""
log_info "This may take 30-60 minutes depending on your internet speed."
log_info "You may be prompted for your sudo password."
log_info ""

read -p "Press Enter to continue or Ctrl+C to cancel..."

# Step 1: Run setup
log_step "Running environment setup..."
if [ -f "./setup-dev-environment.sh" ]; then
    ./setup-dev-environment.sh
else
    echo "Error: setup-dev-environment.sh not found"
    exit 1
fi

# Step 2: Source environment
log_step "Loading environment variables..."
export ANDROID_SDK_ROOT="${HOME}/Android/Sdk"
export ANDROID_HOME="${ANDROID_SDK_ROOT}"
export ANDROID_NDK_HOME="${ANDROID_SDK_ROOT}/ndk/27.2.12479018"
export PATH=$PATH:${ANDROID_HOME}/cmdline-tools/latest/bin
export PATH=$PATH:${ANDROID_HOME}/platform-tools
export PATH=$PATH:${ANDROID_HOME}/emulator
export PATH=$PATH:${ANDROID_HOME}/tools
export PATH=$PATH:${ANDROID_HOME}/tools/bin

# Step 3: Verify Docker access
log_step "Verifying Docker access..."
if ! docker info > /dev/null 2>&1; then
    log_info "Docker requires group membership. Attempting to fix..."

    # Try to start docker if it's not running
    sudo systemctl start docker

    # Try with newgrp (this creates a new shell with docker group)
    if groups | grep -q docker; then
        log_info "You're in the docker group, but need to reload groups"
        log_info "Please run this after the script completes:"
        log_info "  newgrp docker"
        log_info "  ./build-and-test-emulator.sh"
        echo ""
        read -p "Try to continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "Error: Not in docker group. Please log out and back in, then run:"
        echo "  ./build-and-test-emulator.sh"
        exit 1
    fi
fi

# Step 4: Run build and test
log_step "Starting build and test process..."
if [ -f "./build-and-test-emulator.sh" ]; then
    ./build-and-test-emulator.sh
else
    echo "Error: build-and-test-emulator.sh not found"
    exit 1
fi

log_info ""
log_info "=========================================="
log_info "Quick Start Complete!"
log_info "=========================================="
log_info "Check the ./screenshots/ directory for the app screenshot"
log_info ""
