# slint-mobile

A [`cargo-generate`](https://github.com/cargo-generate/cargo-generate) template
for **Slint UI applications targeting Android**. The generated project is a
Rust workspace with a pure-logic `core` crate and a Slint-powered `app` crate
that compiles directly to an APK via `cargo-apk`. No Kotlin or Java source.

## Generate a new project

```sh
cargo install cargo-generate
cargo generate --git https://github.com/<you>/slint-mobile --name my-app
```

You will be prompted for:

| Placeholder        | Example                       | Used in                              |
|--------------------|-------------------------------|--------------------------------------|
| `project-name`     | `my-app`                      | Directory + workspace name           |
| `crate_name`       | `my_app` (auto from above)    | Crate names (`app`, `app_core`)      |
| `android_package`  | `com.example.my_app`          | Android `applicationId` in `app/Cargo.toml` |
| `app_label`        | `My App`                      | Launcher label + window title        |

After generation, the new project has its own `README.md` documenting how to
build and run.

## What's in the generated project

```
my-app/
├── Cargo.toml             # Workspace, default-members = ["app"]
├── rust-toolchain.toml    # stable + aarch64-linux-android target
├── .devcontainer/         # Rust + JDK 17 + Android SDK 34 + NDK r27, pinned
├── .github/workflows/
│   └── ci.yml             # Calls into `justfile`; fmt + clippy + test on every PR; apk on main
├── justfile               # Recipes shared by local dev and CI (just --list)
├── core/                  # Pure-logic rlib (no Slint, no Android)
└── app/                   # Slint cdylib + android_main, packaged by cargo-apk
```

`cargo apk run` in the generated project builds, installs, and launches
on an attached device — no `-p` or `--target` flags needed (handled by
`default-members` and `[package.metadata.android].build_targets`).

The shipped `ci.yml` runs `cargo fmt --check`, `cargo clippy -D warnings`,
and `cargo test --workspace` on every push and pull request, then on
pushes to `main`/`master` cross-compiles to `aarch64-linux-android` and
uploads the resulting APK as a build artifact. Generated projects therefore
come out of the gate with green CI.

## Template internals

Files that drive the templating:

- [`cargo-generate.toml`](cargo-generate.toml) — placeholder definitions
  (`android_package`, `app_label`), the `ignore` list, and the post-hook
  registration.
- [`post-script.rhai`](post-script.rhai) — renames `_README.md` to
  `README.md` after generation.
- [`_README.md`](_README.md) — the README that ships with the generated
  project (carries liquid placeholders).

To keep Rust source files free of liquid syntax (so the template repo
stays editor-friendly), the core crate's templated package name
`{{crate_name}}_core` is renamed to the stable alias `app_core` in
`workspace.dependencies`. Source files just `use app_core::...`.

## Iterating on this template

The template repo itself will not `cargo check` cleanly — the
`{{crate_name}}` placeholders in `Cargo.toml` files aren't valid Cargo
identifiers until cargo-generate substitutes them. To smoke-test changes,
generate into a scratch directory:

```sh
cargo generate --path . --name scratch --define android_package=com.example.scratch --define app_label="Scratch"
cd scratch
cargo apk build
```
