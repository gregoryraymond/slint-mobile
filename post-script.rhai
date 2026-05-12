// Post-generation hook for cargo-generate.
//
// `_README.md` in the template repo carries the generated project's README
// with liquid placeholders. The template repo's own `README.md` (the GitHub
// landing page) is excluded from generation via `ignore` in
// cargo-generate.toml, so after generation we rename `_README.md` into the
// final `README.md`. We then delete this script itself so the generated
// project is clean.

file::rename("_README.md", "README.md");
file::delete("post-script.rhai");
