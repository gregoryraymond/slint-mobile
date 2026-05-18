<a name="top"></a>

# slint-mobile

[![Live demo](https://img.shields.io/badge/demo-live-1d76db?style=flat-square)](https://gregoryraymond.github.io/slint-mobile/)
[![License](https://img.shields.io/badge/license-MIT_OR_Apache--2.0-blue?style=flat-square)](#-license)
[![Slint](https://img.shields.io/badge/Slint-1.x-2379f4?style=flat-square)](https://slint.dev)
[![Rust](https://img.shields.io/badge/rust-1.74%2B-orange?style=flat-square)](https://www.rust-lang.org)
[![Target](https://img.shields.io/badge/target-Android-3DDC84?style=flat-square)](#)
[![Pages](https://github.com/gregoryraymond/slint-mobile/actions/workflows/pages.yml/badge.svg)](https://github.com/gregoryraymond/slint-mobile/actions/workflows/pages.yml)
[![Template CI](https://github.com/gregoryraymond/slint-mobile/actions/workflows/template.yml/badge.svg)](https://github.com/gregoryraymond/slint-mobile/actions/workflows/template.yml)

A [`cargo-generate`](https://github.com/cargo-generate/cargo-generate)
template for **Slint UI applications targeting Android**, written in
pure Rust. Sister project to
[`slint-mobile-components`](https://github.com/gregoryraymond/slint-mobile-components)
— this template scaffolds the app, that crate supplies the visual
language.

> 📱 **[See the design system in action →](https://gregoryraymond.github.io/slint-mobile/)**
> The Pages site previews the `slint-mobile-components` screen
> catalogue — 145 page templates rendered in the browser — so you can
> audition what's available before generating a project. Same UI as
> the desktop viewer, compiled to wasm.

The generated project is a Rust workspace with a pure-logic `core`
crate and a Slint-powered `app` crate that compiles directly to an
APK via [`cargo-apk2`](https://github.com/mzdk100/cargo-apk2). No
Kotlin / Java by default; opt in by adding a glue crate (e.g.
`slint-android-gestures`) or dropping `.kt` files into `app/kotlin/`.

## Table of contents

- [📱 About](#-about)
- [🚀 Generate a new project](#-generate-a-new-project)
- [✨ What's in the generated project](#-whats-in-the-generated-project)
- [🎨 Pair with slint-mobile-components](#-pair-with-slint-mobile-components)
- [🧱 Template internals](#-template-internals)
- [🛠️ Iterating on this template](#%EF%B8%8F-iterating-on-this-template)
- [🤝 Contributing](#-contributing)
- [☕ Support the project](#-support-the-project)
- [📃 License](#-license)

## 📱 About

This template solves the cold-start problem for Slint-on-Android: it
hands you a workspace that already builds for the device, runs in CI,
ships with a documented justfile, and is pre-wired for the
[`slint-mobile-components`](https://github.com/gregoryraymond/slint-mobile-components)
design system. The pure-Rust path means no `gradlew`, no Android
Studio configuration drama, no JVM glue you didn't ask for — `cargo
apk2 build` is the whole build.

`cargo-apk2` (the actively-maintained fork of `cargo-apk`) handles
NDK invocation, Kotlin/Java compilation when present, and APK
packaging. The generated project's `.devcontainer/Dockerfile` pins
Rust + JDK 17 + Android SDK 34 + NDK r27 so the build is
reproducible the same day you generate it as it is six months later.

## 🚀 Generate a new project

```sh
cargo install cargo-generate
cargo generate --git https://github.com/gregoryraymond/slint-mobile --name my-app
```

You will be prompted for:

| Placeholder        | Example                       | Used in                                       |
|--------------------|-------------------------------|-----------------------------------------------|
| `project-name`     | `my-app`                      | Directory + workspace name                    |
| `crate_name`       | `my_app` (auto from above)    | Crate names (`app`, `app_core`)               |
| `android_package`  | `com.example.my_app`          | Android `applicationId` in `app/Cargo.toml`   |
| `app_label`        | `My App`                      | Launcher label + window title                 |

After generation, the new project has its own `README.md` documenting
how to build and run.

## ✨ What's in the generated project

```
my-app/
├── Cargo.toml             # Workspace, default-members = ["app"]
├── rust-toolchain.toml    # stable + aarch64-linux-android target
├── .devcontainer/         # Rust + JDK 17 + Android SDK 34 + NDK r27, pinned
├── .github/workflows/
│   └── ci.yml             # fmt + clippy + test on PRs; apk build on main
├── justfile               # Recipes shared by local dev and CI (just --list)
├── core/                  # Pure-logic rlib (no Slint, no Android)
└── app/                   # Slint cdylib + android_main, packaged by cargo-apk2
```

`cargo apk2 run` in the generated project builds, installs, and
launches on an attached device — no `-p` or `--target` flags needed
(handled by `default-members` and
`[package.metadata.android].build_targets`).

The shipped `ci.yml` runs `cargo fmt --check`, `cargo clippy -D
warnings`, and `cargo test --workspace` on every push and pull
request, then on pushes to `main` / `master` cross-compiles to
`aarch64-linux-android` and uploads the resulting APK as a build
artifact. Generated projects therefore come out of the gate with
green CI and a downloadable APK on every release-worthy commit.

The split between `core/` (pure logic, builds on the host) and `app/`
(Slint UI + Android entry point) is deliberate: most logic can be
developed and tested with `cargo test` on a laptop, with the
emulator only in the loop when you need to confirm something visual
or device-specific.

## 🎨 Pair with slint-mobile-components

The template is set up so that adding the
[`slint-mobile-components`](https://github.com/gregoryraymond/slint-mobile-components)
design system is a few-line change rather than a fork. The flow is:

1. Clone or vendor `slint-mobile-components` next to your generated
   project.
2. Add it as a normal Cargo dep + build-dep in `app/Cargo.toml`.
3. Call `slint_mobile_components::library_paths()` from `build.rs`
   to register every `@mobile-theme` / `@mobile-components` /
   `@mobile-pages-*` alias in one line.
4. Import any of the 145 page templates by path in your `.slint`
   files: `import { HomePage } from "@mobile-pages-misc/home.slint";`.

The components library's
[README](https://github.com/gregoryraymond/slint-mobile-components)
documents the consumption pattern in full and links to a live wasm
catalogue you can scroll through before deciding what you want.

## 🧱 Template internals

Files that drive the templating:

- [`cargo-generate.toml`](cargo-generate.toml) — placeholder
  definitions (`android_package`, `app_label`), the `ignore` list, and
  the post-hook registration.
- [`post-script.rhai`](post-script.rhai) — renames `_README.md` →
  `README.md` and `_ci.yml` → `.github/workflows/ci.yml` after
  generation.
- [`_README.md`](_README.md) — the README that ships with the
  generated project (carries liquid placeholders).
- [`_ci.yml`](_ci.yml) — the GitHub Actions workflow that ships with
  the generated project. Stored at the template root with a leading
  underscore so GitHub Actions does **not** run it against the
  template repo (it would fail because the workspace `Cargo.toml`
  still contains `{{crate_name}}` placeholders). Only
  `.github/workflows/template.yml` runs on the template repo itself.

To keep Rust source files free of liquid syntax (so the template repo
stays editor-friendly), the core crate's templated package name
`{{crate_name}}_core` is renamed to the stable alias `app_core` in
`workspace.dependencies`. Source files just `use app_core::...`.

## 🛠️ Iterating on this template

The template repo itself will not `cargo check` cleanly — the
`{{crate_name}}` placeholders in `Cargo.toml` files aren't valid Cargo
identifiers until `cargo-generate` substitutes them. To smoke-test
changes, generate into a scratch directory:

```sh
cargo generate --path . --name scratch \
  --define android_package=com.example.scratch \
  --define app_label="Scratch"
cd scratch
cargo apk2 build
```

The `.github/workflows/template.yml` workflow on this repo does exactly
that on every PR so template regressions surface before they reach
users.

## 🤝 Contributing

Issues and PRs welcome. The bias is toward keeping the template small
and free of opinionated dependencies — the generated project should
build on a fresh Rust install with just the Android SDK / NDK in
place, and nothing else.

If you've got an opinion on what a Slint-on-Android scaffold should
default to (linting setup, observability, signing config, multi-arch
build targets, a flutter-style hot reload story), open an issue and
say so. The next thing built is usually the next thing someone
actually needs.

## ☕ Support the project

If slint-mobile has saved you a day of wiring up `cargo-apk2`,
Android SDK paths, and Rust target installation — a coffee keeps
weekend hacking time available for it.

[![Buy me a coffee](https://img.shields.io/badge/buy_me_a_coffee-FFDD00?logo=buy-me-a-coffee&logoColor=000&style=for-the-badge)](https://buymeacoffee.com/gregoryraymond)
[![GitHub Sponsors](https://img.shields.io/badge/GitHub-sponsor-EA4AAA?logo=github-sponsors&logoColor=white&style=for-the-badge)](https://github.com/sponsors/gregoryraymond)

One-offs are great. If you're a company shipping Slint-on-Android in
a product, a small recurring sponsorship via GitHub Sponsors is more
useful — it gives a rough sense of how many real users depend on the
template, which affects how much I'm willing to change in a refactor.

## 📃 License

Dual-licensed under either [MIT](LICENSE-MIT) or
[Apache-2.0](LICENSE-APACHE) at your option.

The template itself uses Slint under its [Royalty-free
licence](https://slint.dev/pricing) — see Slint's pricing page for
the commercial terms that apply to apps built with it.

---

<sub>[↑ Back to top](#top)</sub>
