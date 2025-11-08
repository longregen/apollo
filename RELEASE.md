# Automated Release Process

This document explains how the Apollo app release process is automated using GitHub Actions.

## Overview

The project includes automated CI/CD workflows that:
- Build the APK on every pull request (for validation)
- Build and create releases when a version tag is pushed
- Automatically attach all APK variants to the GitHub Release

## Release Process

### 1. Creating a Release

To create a new release:

```bash
# Create and push a version tag matching the pattern v*
git tag -a v55.4 -m "Release version 55.4"
git push origin v55.4
```

The tag format should follow semantic versioning: `vX.Y.Z` or `vX.Y`

### 2. Automatic Workflow Execution

When you push a version tag, GitHub Actions automatically:

1. **Builds the APK**
   - Uses the `android/Dockerfile` for reproducible builds
   - Compiles native libraries (Rust, Go)
   - Generates APK variants for all supported architectures:
     - `apolloui-prod-arm64-v8a-release-unsigned.apk` (64-bit ARM)
     - `apolloui-prod-armeabi-v7a-release-unsigned.apk` (32-bit ARM)
     - `apolloui-prod-x86-release-unsigned.apk` (32-bit x86)
     - `apolloui-prod-x86_64-release-unsigned.apk` (64-bit x86)
   - Generates `mapping.txt` for crash analytics

2. **Creates a GitHub Release**
   - Automatically attaches all APK variants
   - Attaches the mapping file
   - Generates release notes from commit history
   - Sets the release as non-draft and non-prerelease

3. **Saves Artifacts**
   - APK files are available in GitHub Actions artifacts
   - APK files are attached to the GitHub Release page

## Workflows

### build-release.yml

**Trigger:** Push to tags matching `v*`

**Steps:**
1. Set up Docker build environment
2. Check out the code
3. Build APK using Docker
4. Upload artifacts to GitHub Actions
5. Create a GitHub Release with all APK files

**Example tag patterns that trigger the workflow:**
- `v55.4` ✅
- `v1.0` ✅
- `v2.3.5` ✅
- `release-55.4` ❌ (doesn't match pattern)

### pr.yml

**Trigger:** Pull requests

**Steps:**
1. Validates the Gradle wrapper
2. Builds APK for verification
3. Uploads APK as artifact for review

## Accessing Releases

After pushing a tag:

1. **GitHub Release Page:** https://github.com/longregen/apollo/releases
2. **GitHub Actions Artifacts:** Check the workflow run details
3. **Direct Download:** Download APK from the GitHub Release page

## Build Requirements

The automated build requires no manual setup:
- Runs on `ubuntu-24.04` GitHub-hosted runners
- Uses Docker for isolated, reproducible builds
- Automatically handles all dependencies (Android NDK, Go, Rust)

## Troubleshooting

### Release Not Created
- Check that the tag matches the pattern `v*`
- Verify the tag push succeeded: `git push origin <tag-name>`
- Check GitHub Actions workflow logs

### Build Failures
1. Check the workflow logs in GitHub Actions
2. Review the Docker build output
3. Verify all code is committed and pushed

### APK Not Attached to Release
- Verify the build completed successfully
- Check that the APK files were generated
- Confirm the Create GitHub Release step executed

## Local Testing (Optional)

To test the build locally (requires Docker, Android NDK, Go, Rust):

```bash
# Build reproducibly using Docker
mkdir -p apk
DOCKER_BUILDKIT=1 docker build -f android/Dockerfile -o apk .
```

For more build instructions, see [BUILD.md](BUILD.md).
