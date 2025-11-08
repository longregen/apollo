# Apollo Android Emulator Setup and Testing Guide

This guide provides step-by-step instructions to set up a complete Android development environment on Ubuntu 24.04 and test the Apollo app on an Android emulator.

## Prerequisites

- Ubuntu 24.04 LTS
- At least 16 GB RAM
- At least 60 GB free disk space
- Internet connection
- sudo privileges

## Quick Start

### Step 1: Setup Development Environment

Run the setup script to install all required dependencies:

```bash
chmod +x setup-dev-environment.sh
./setup-dev-environment.sh
```

This script will install:
- Android SDK and command-line tools
- Android NDK (required for native code compilation)
- Docker (required for building native libraries)
- Android Emulator with Google APIs
- KVM for hardware acceleration
- Required build tools

**Important:** After the setup completes, you must either:
- Log out and log back in, OR
- Run: `source ~/.bashrc`

This ensures all environment variables and group permissions take effect.

### Step 2: Build and Test on Emulator

After sourcing the environment, build the app and test on the emulator:

```bash
chmod +x build-and-test-emulator.sh
./build-and-test-emulator.sh
```

This script will:
1. Build native libraries (libwallet/librs)
2. Bootstrap gomobile
3. Build libwallet for Android
4. Build the Apollo APK (local debug flavor by default)
5. Start the Android emulator
6. Install the APK on the emulator
7. Launch the app
8. Take a screenshot

Screenshots are saved to `./screenshots/` directory.

## What Gets Installed

### Android SDK Components
- Platform Tools (adb, fastboot, etc.)
- Android Platform API 34
- Build Tools 34.0.0
- Android NDK 27.2.12479018
- Android Emulator
- System Image: Android 34 with Google APIs (x86_64)

### Development Tools
- Docker CE (latest)
- OpenJDK 17
- KVM for emulator hardware acceleration
- scrcpy (for screen mirroring and capture)

### Environment Variables

The setup script adds these to your `~/.bashrc`:

```bash
export ANDROID_HOME="${HOME}/Android/Sdk"
export ANDROID_SDK_ROOT="${HOME}/Android/Sdk"
export ANDROID_NDK_HOME="${HOME}/Android/Sdk/ndk/27.2.12479018"
export PATH=$PATH:${ANDROID_HOME}/cmdline-tools/latest/bin
export PATH=$PATH:${ANDROID_HOME}/platform-tools
export PATH=$PATH:${ANDROID_HOME}/emulator
export PATH=$PATH:${ANDROID_HOME}/tools
export PATH=$PATH:${ANDROID_HOME}/tools/bin
```

## Customizing the Build

Edit `build-and-test-emulator.sh` to change build options:

```bash
BUILD_FLAVOR="local"   # Options: local, regtest, prod, dogfood
BUILD_TYPE="debug"     # Options: debug, release, minified
```

### Build Flavors

- **local**: Local development with localhost backend
- **regtest**: Remote regtest environment
- **prod**: Production build (connects to production servers)
- **dogfood**: Internal beta build

### Build Types

- **debug**: Debug build with debugging enabled
- **release**: Release build with ProGuard/R8 optimization
- **minified**: Debug build with minification enabled

## Manual Build Steps

If you prefer to build manually:

### 1. Build Native Libraries

```bash
cd libwallet/librs
./makelibs.sh
cd ../..
```

### 2. Bootstrap Gomobile

```bash
./tools/bootstrap-gomobile.sh
```

### 3. Build Android Libwallet

```bash
./tools/libwallet-android.sh
```

### 4. Build APK

```bash
./gradlew :android:apolloui:assembleLocalDebug
```

Or use system Gradle:

```bash
gradle :android:apolloui:assembleLocalDebug
```

### 5. Start Emulator

```bash
emulator -avd Apollo_Test_AVD &
adb wait-for-device
```

### 6. Install and Run

```bash
adb install -r android/apolloui/build/outputs/apk/local/debug/apolloui-local-debug.apk
adb shell am start -n io.muun.apollo.local/.presentation.ui.launcher.LauncherActivity
```

### 7. Take Screenshot

```bash
mkdir -p screenshots
adb exec-out screencap -p > screenshots/apollo_screenshot.png
```

## Emulator Management

### List Available AVDs
```bash
avdmanager list avd
```

### Start Emulator
```bash
emulator -avd Apollo_Test_AVD
```

### Start Emulator Headless (No GUI)
```bash
emulator -avd Apollo_Test_AVD -no-window -no-audio &
```

### List Running Devices
```bash
adb devices
```

### Stop Emulator
```bash
adb emu kill
```

### Create Custom AVD
```bash
avdmanager create avd \
    -n MyCustomAVD \
    -k "system-images;android-34;google_apis;x86_64" \
    -d "pixel_5"
```

## Troubleshooting

### Emulator Won't Start

**Check KVM support:**
```bash
kvm-ok
```

If KVM is not available, the emulator will run in software mode (slower).

**Check emulator logs:**
```bash
tail -f /tmp/emulator.log
```

### Build Fails

**Check environment variables:**
```bash
echo $ANDROID_SDK_ROOT
echo $ANDROID_NDK_HOME
```

**Verify NDK installation:**
```bash
ls -la $ANDROID_NDK_HOME
```

**Check Docker status:**
```bash
docker info
```

If Docker permission denied:
```bash
sudo usermod -aG docker $USER
# Then log out and back in
```

### App Won't Install

**Check device connection:**
```bash
adb devices
```

**Clear app data if reinstalling:**
```bash
adb shell pm clear io.muun.apollo.local
```

### Screenshot is Black/Corrupted

Wait longer for app to fully load before taking screenshot. Edit `build-and-test-emulator.sh` and increase the sleep time:

```bash
sleep 15  # Instead of sleep 10
```

### Gradle Download Issues

If Gradle wrapper fails to download, use system Gradle:
```bash
gradle --version  # Verify installation
gradle :android:apolloui:assembleLocalDebug
```

## Performance Tips

### Enable Hardware Acceleration
Make sure you're in the KVM group:
```bash
groups | grep kvm
```

If not:
```bash
sudo usermod -aG kvm $USER
# Log out and back in
```

### Increase Emulator RAM
Edit the AVD config:
```bash
nano ~/.android/avd/Apollo_Test_AVD.avd/config.ini
```

Change:
```ini
hw.ramSize=2048
```

### Use Faster System Image
x86_64 images are faster than ARM on x86_64 hosts. The setup script already uses this.

## Disk Space Management

The Android SDK can consume significant disk space:

### Check SDK disk usage:
```bash
du -sh ~/Android/Sdk
```

### Remove unused system images:
```bash
sdkmanager --uninstall "system-images;android-XX;..."
```

### Clean build artifacts:
```bash
./gradlew clean
rm -rf ~/.gradle/caches/
```

## Docker Configuration

The native library build requires Docker with sufficient resources:

### Recommended Docker Settings:
- Memory: 4 GB minimum, 8 GB recommended
- Disk: 20 GB minimum
- CPUs: 2 minimum, 4 recommended

Check Docker resource usage:
```bash
docker stats
```

## Reproducible Builds

For reproducible builds using Docker (as per BUILD.md):

```bash
mkdir -p apk
DOCKER_BUILDKIT=1 docker build -f android/Dockerfile -o apk .
```

This requires:
- Docker with BuildKit enabled
- At least 16 GB RAM allocated to Docker
- At least 60 GB free disk space

## Additional Resources

- [Android SDK Command Line Tools](https://developer.android.com/studio/command-line)
- [Android Emulator](https://developer.android.com/studio/run/emulator-commandline)
- [Apollo BUILD.md](BUILD.md)

## Support

If you encounter issues:

1. Check the logs at `/tmp/emulator.log`
2. Run with verbose output: `bash -x ./build-and-test-emulator.sh`
3. Verify all environment variables are set correctly
4. Ensure Docker daemon is running
5. Check that you're in the docker and kvm groups

## Environment Verification

Run these commands to verify your setup:

```bash
# Java version
java -version

# Gradle version
gradle --version

# Go version
go version

# Android SDK
sdkmanager --list_installed

# Docker
docker --version
docker info

# ADB
adb version

# Emulator
emulator -list-avds

# Environment variables
env | grep ANDROID
```

All checks should pass before attempting to build.
