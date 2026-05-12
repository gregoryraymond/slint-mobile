# {{project-name}}

A [Slint](https://slint.dev) UI compiled to an Android APK. All application
logic is in Rust; there is no Kotlin or Java source.

## Layout

```
{{project-name}}/
├── Cargo.toml          # Workspace + shared dependencies + default-members
├── rust-toolchain.toml # Pins stable + aarch64-linux-android target
├── core/               # Pure-logic crate (rlib). No Slint, no Android.
│   ├── Cargo.toml      # package = "{{crate_name}}_core"
│   └── src/lib.rs
└── app/                # UI + Android entry point (cdylib).
    ├── Cargo.toml      # package = "{{crate_name}}"; android metadata
    ├── build.rs        # Invokes slint-build on ui/main.slint
    ├── ui/main.slint   # Declarative UI
    ├── android-res/    # Optional Android resources (placeholder)
    ├── android-assets/ # Optional Android assets (placeholder)
    └── src/lib.rs      # android_main entry point
```

The split is deliberate: `core/` builds and tests on the host with plain
`cargo test`, so most logic can be developed without an emulator. `app/` is
the only crate that pulls in Slint and Android. The core crate is renamed
to the stable in-source alias `app_core` via `workspace.dependencies`, so
Rust source files don't carry the project name in their imports.

## One-time setup

The fastest path is to open this repo in the provided dev container — it
ships Rust + cargo-apk + JDK 17 + Android SDK 34 + NDK r27 pre-installed
and pinned. See [`.devcontainer/Dockerfile`](.devcontainer/Dockerfile) for
the exact versions. To set things up manually instead:

1. Install the Android target:
   ```sh
   rustup target add aarch64-linux-android
   ```
2. Install [`cargo-apk`](https://github.com/rust-mobile/cargo-apk):
   ```sh
   cargo install cargo-apk
   ```
3. Install Android Studio (or the command-line tools) and a recent NDK.
   Export the SDK and NDK locations:
   ```sh
   export ANDROID_HOME="$HOME/Android/Sdk"
   export ANDROID_NDK_ROOT="$ANDROID_HOME/ndk/<version>"
   ```
   `cargo-apk` also needs a JDK on `PATH` (or `JAVA_HOME` set).

## Build & run

Everyday commands live in the root `justfile`. Install `just` once with
`cargo install just --locked` (or `brew install just`, `apt install just`,
etc.), then:

```sh
just                 # list available recipes (default action)
just fmt             # cargo fmt --all
just clippy          # cargo clippy ... -D warnings
just test            # cargo test --workspace
just build           # debug APK
just release         # release APK at target/aarch64-linux-android/release/apk/
just run             # build, install, launch — starts an emulator if none is running
just ci              # fmt-check + clippy + test (mirrors CI on PRs)
```

`just run` will reuse a running emulator or attached device if there is
one; otherwise it starts an emulator from your AVD list (override with
`AVD=<name> just run`) and waits for boot before invoking `cargo apk run`.

`just run` works without `-p` or `--target` because the workspace sets
`default-members = ["app"]` and `app/Cargo.toml` pins
`build_targets = ["aarch64-linux-android"]`. The resulting APK lands at
`target/aarch64-linux-android/release/apk/{{crate_name}}.apk`.

If you prefer raw cargo invocations they all still work — `just` is
a convenience layer, not a wrapper that adds new behavior.

## Adding a JVM-side Rust shim later

This scaffold renders directly via `NativeActivity` — no Kotlin or Java is
involved. If you later need a privileged Android `Service` (which must be a
JVM class), the natural extension is:

- Keep `core/` as the shared logic crate.
- Add a `service/` crate exposing a `uniffi`-generated SDK plus a small
  Kotlin file that subclasses `android.app.Service` and delegates into it.
- `app/` and `service/` both depend on `core/`.

## CI

`.github/workflows/ci.yml` ships with this project. Each job calls into
the same `justfile` recipes you use locally:

- `just fmt-check` and `just clippy` on every push and PR
- `just test` on every push and PR
- `just apk` on pushes to `main`/`master`, uploading the resulting `.apk`
  as the `apk-aarch64` artifact

This keeps CI and local development in sync — if `just ci` is green on
your laptop, the PR's lint/test jobs will be too.

The Android build job sets up JDK 17, the Android SDK (platform 34,
build-tools 34.0.0), NDK r27, and `cargo-apk` — mirroring what the
`.devcontainer/Dockerfile` provides locally.

## Notes

- The Slint feature flag `backend-android-activity-06` tracks
  `android-activity` 0.6.x. When Slint moves to a newer `android-activity`
  major version, update the feature name in the workspace `Cargo.toml`.
- `min_sdk_version = 24` is the floor for Skia + modern `android-activity`.
  Lower than that and the build will technically succeed but the renderer
  will fail on real devices.
- The `android-res/` and `android-assets/` directories are referenced from
  `app/Cargo.toml`. Drop drawables, strings, or other assets there as the
  app grows.
- Android package id: `{{android_package}}` — change in `app/Cargo.toml`.
