# Justfile for the Slint Android app.
#
# Install just locally with: `cargo install just --locked`
# (or `brew install just`, `apt install just`, etc.)
# Run `just` with no arguments to see the recipe list. CI under
# .github/workflows/ci.yml invokes the same recipes you run locally.

set shell := ["bash", "-cu"]

# Show available recipes
default:
    @just --list

# Format all Rust code in place
fmt:
    cargo fmt --all

# Lint with clippy, treating warnings as errors
clippy:
    cargo clippy --workspace --all-targets -- -D warnings

# Run host-side workspace tests
test:
    cargo test --workspace

# Build a debug APK at target/aarch64-linux-android/debug/apk/
build:
    cargo apk build

# Build a release APK at target/aarch64-linux-android/release/apk/
release:
    cargo apk build --release

# Build, install, and launch on a running emulator or attached device.
# If nothing is connected, starts an Android emulator first. Pass an AVD
# name via $AVD; otherwise the first one from `emulator -list-avds` wins.
run:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! adb get-state > /dev/null 2>&1; then
        emulator_bin="${ANDROID_HOME:?ANDROID_HOME is not set}/emulator/emulator"
        avd="${AVD:-$("$emulator_bin" -list-avds | head -n 1)}"
        if [ -z "$avd" ]; then
            echo "No AVD found. Create one with:"
            echo "  sdkmanager 'system-images;android-34;default;x86_64'"
            echo "  avdmanager create avd -n slint -k 'system-images;android-34;default;x86_64'"
            exit 1
        fi
        echo "Starting emulator: $avd"
        "$emulator_bin" -avd "$avd" -no-boot-anim -no-snapshot > /dev/null 2>&1 &
        adb wait-for-device
        until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
            sleep 2
        done
        echo "Emulator ready."
    fi
    cargo apk run

# Full local CI pipeline (mirrors what runs on PRs)
ci: fmt-check clippy test

# --- private helpers (callable, but hidden from `just --list`) -------------

# CI-only: verify formatting without modifying files
[private]
fmt-check:
    cargo fmt --all -- --check

# CI-only: install Linux apt packages Slint's Skia renderer needs to build
[private]
install-host-deps:
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
        pkg-config \
        libfontconfig1-dev \
        libfreetype6-dev \
        clang \
        cmake \
        ninja-build
