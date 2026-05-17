# {{project-name}}

A [Slint](https://slint.dev) UI compiled to an Android APK. All application
logic is in Rust; the only Kotlin/Java in the build is whatever JVM-side
glue crates pull in (e.g. `slint-android-gestures` for multi-touch). For a
"pure native, no JVM glue at all" app the only thing left in `classes.dex`
is the bundled `NativeActivity` Slint already needs.

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
ships Rust + cargo-apk2 + JDK 17 + Kotlin + Android SDK 34 + NDK r27
pre-installed and pinned. See [`.devcontainer/Dockerfile`](.devcontainer/Dockerfile)
for the exact versions. To set things up manually instead:

1. Install the Android target:
   ```sh
   rustup target add aarch64-linux-android
   ```
2. Install [`cargo-apk2`](https://github.com/mzdk100/cargo-apk2) — the
   actively-maintained fork of `cargo-apk` that adds Kotlin/Java source
   compilation and declarative activity/service blocks:
   ```sh
   cargo install cargo-apk2 --locked
   ```
3. Install Android Studio (or the command-line tools) and a recent NDK.
   Export the SDK and NDK locations:
   ```sh
   export ANDROID_HOME="$HOME/Android/Sdk"
   export ANDROID_NDK_ROOT="$ANDROID_HOME/ndk/<version>"
   ```
   `cargo-apk2` also needs a JDK on `PATH` (or `JAVA_HOME` set), plus
   `KOTLIN_HOME` pointing at an unpacked Kotlin distribution from
   <https://kotlinlang.org/docs/command-line.html> — only required if
   any of your dependencies actually ship Kotlin source; pure-Rust apps
   build without it.

## Build & run

Everyday commands live in the root `justfile`. Install `just` once with
`cargo install just --locked` (or `brew install just`, `apt install just`,
etc.), then:

```sh
just                 # list available recipes (default action)
just fmt             # cargo fmt --all
just clippy          # cargo clippy ... -D warnings
just test            # cargo test --workspace
just build           # debug APK (multi-arch: aarch64 + x86_64)
just release         # release APK at target/release/apk/
just setup-emulator  # create the "slint" AVD + download its system image (once)
just run             # build, install, launch on emulator/device
just ci              # fmt-check + clippy + test (mirrors CI on PRs)
```

### First-run flow

1. `just setup-emulator` — creates an AVD named `slint` and downloads the
   matching `android-34` system image (~700 MB; ABI auto-picked to match
   your host: `x86_64` on Intel/AMD, `arm64-v8a` on Apple Silicon).
2. `just run` — builds a debug APK, starts the `slint` emulator (or reuses
   any device/emulator already on `adb devices`), waits for it to finish
   booting, then installs and launches the app.

Subsequent `just run` invocations reuse the running emulator, so they
take only as long as the rebuild + install. Set `AVD=<name>` to target a
different AVD; close the emulator window when you're done.

The APK is multi-arch (`aarch64` + `x86_64`) so the same artifact installs
on real devices and on the default emulator system image.

`just run` works without `-p` or `--target` because the workspace sets
`default-members = ["app"]` and `app/Cargo.toml` pins
`build_targets = ["aarch64-linux-android"]`. The resulting APK lands at
`target/aarch64-linux-android/release/apk/{{crate_name}}.apk`.

If you prefer raw cargo invocations they all still work — `just` is
a convenience layer, not a wrapper that adds new behavior.

## Adding JVM-side glue

This scaffold renders directly via `NativeActivity` — no Kotlin or Java
in your tree by default. cargo-apk2 makes adding it incremental:

- **Drop-in glue from a crate** — add the crate as a dep, point its
  `build.rs` helper at a `kotlin/` directory, set `kotlin_sources =
  "kotlin"` in `[package.metadata.android]`, and the JVM classes land in
  the APK's `classes.dex` on a normal `just build`. See
  [`slint-android-gestures`](https://github.com/gregoryraymond/slint-mapping/tree/main/crates/slint-android-gestures)
  for a complete example (multi-touch pinch wrapper).
- **Hand-written glue** — drop `.kt` files into `app/kotlin/<package>/`
  and the same `kotlin_sources = "kotlin"` config picks them up. Useful
  for one-off Android API access (location permissions, push, billing).
- **Service crates** — for a privileged Android `Service` you can wrap
  the JVM subclass in its own crate, ship its `.kt` the same way, and
  declare it via `[[package.metadata.android.service]]` (a cargo-apk2
  feature the legacy cargo-apk lacked).

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
build-tools 34.0.0), NDK r27, `cargo-apk2`, and Kotlin — mirroring what
the `.devcontainer/Dockerfile` provides locally.

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
