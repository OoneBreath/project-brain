# Contributing to Project Brain

Thanks for your interest in improving Project Brain! It's a small, focused
project — a Claude Code skill plus a few hooks and templates — so contributing
is lightweight.

## Ways to help

- **Report a bug or rough edge** — open an [issue](https://github.com/OoneBreath/project-brain/issues)
  describing what you expected vs. what happened. Include your OS and Claude Code version.
- **Suggest an improvement** — open an issue first so we can discuss the idea
  before you spend time on a PR.
- **Send a pull request** — for typos, docs, and small fixes, go straight ahead.
  For anything that changes behavior, please open an issue first.

## Pull request guidelines

1. Fork the repo and create a branch from `main`.
2. Keep changes focused — one logical change per PR.
3. Match the existing style: plain Markdown, no new dependencies, no build step.
4. If you touch the skill, test it locally: run `./install.sh`, then start a
   Claude Code session and exercise the `/project-brain` flow you changed.
5. Update `CHANGELOG.md` and bump the version in `SKILL.md` + `.claude-plugin/plugin.json`
   if your change is user-visible.
6. Describe what you changed and why in the PR body.

## Scope

Project Brain intentionally stays minimal: plain-text `.project-brain/` files,
a small index, and on-demand topic files. Please keep new features aligned with
that philosophy — portability and zero lock-in over cleverness.

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
