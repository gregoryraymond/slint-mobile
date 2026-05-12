// Post-generation hook for cargo-generate.
//
// Two renames live here, both for the same reason: the source paths in the
// template repo must be inert as far as GitHub / Cargo are concerned, so
// that the template repo itself doesn't trip its own toolchain. The hook
// puts each file at its real destination once it lands in the generated
// project.
//
//   `_README.md`   -> `README.md`
//       The template repo's own `README.md` (the GitHub landing page) is
//       excluded from generation via `ignore` in cargo-generate.toml.
//       `_README.md` carries the generated project's README with liquid
//       placeholders and is renamed into place here.
//
//   `_ci.yml`      -> `.github/workflows/ci.yml`
//       The generated project's CI workflow. Kept at the template root with
//       a leading underscore so GitHub Actions does NOT auto-run it on the
//       template repo (it would fail against unsubstituted `{{ ... }}`
//       placeholders in Cargo.toml). Only the template-CI workflow stays
//       under `.github/workflows/` in the template repo.

file::rename("_README.md", "README.md");
file::rename("_ci.yml", ".github/workflows/ci.yml");
file::delete("post-script.rhai");
