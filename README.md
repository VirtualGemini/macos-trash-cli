# macos-trash-cli

English | [简体中文](README.zh-CN.md)

Use it like `rm`, with files going to macOS Trash. The command is `tc`:

```sh
tc report.txt build/
```

`tc` moves files and directories instead of permanently deleting them. Find accidentally removed
items in Finder’s Trash while they remain there. Moving items to Trash does not immediately free disk space.

<a id="installation-and-release"></a>

## Install

Requires macOS 13+. Homebrew builds from source and needs an active Apple Swift 6+ toolchain
from Xcode or Command Line Tools (`xcrun swift --version`). The toolchain may require a newer macOS.

```sh
brew install VirtualGemini/tap/macos-trash-cli-beta
tc --version
```

Current release: **v0.1.0-beta.1**. The beta formula installs `tc`; the stable formula is not yet available.
The first Trash operation may ask permission for your terminal or `tc` to control Finder.

Alternatively, download a universal Apple Silicon / Intel archive from
[GitHub Releases](https://github.com/VirtualGemini/macos-trash-cli/releases/tag/v0.1.0-beta.1)
and verify its accompanying SHA-256 file. These binaries are unsigned and may require Gatekeeper approval.

## Features

- **System Trash:** move files and whole directories; move symbolic links without following their targets.
- **Safety checks:** reject root execution, protected paths such as `/`, your home and current directory,
  and explicit parent-directory expressions such as `..`. Force options cannot bypass these checks.
- **Preview:** inspect the planned operation with `--dry-run` before moving anything.
- **Confirmation:** choose automatic, once-per-batch, per-item, or no prompts.
- **Ordered batches:** process paths in order, continue after item failures, or stop on the first error.
- **Scriptable output:** get JSON results with exact Trash destinations, verbose details, or quiet output.

## Everyday use

### Use familiar `rm` commands

For zsh, make `rm` call `tc` by adding this line to `~/.zshrc`:

```sh
alias rm='tc'
```

Run `source ~/.zshrc` or open a new zsh terminal. Then use familiar commands:

```sh
rm report.txt                   # Move a file to Trash
rm -rf build/                   # Move a directory to Trash without prompting
rm --dry-run report.txt build/   # Preview before moving
```

This changes your shell alias, not `/bin/rm`. Only shells that load the alias use it;
scripts and Agents may invoke `rm` directly. Supported flags and compatibility differences are listed below.

### Recover from an Agent’s mistaken removal

When an Agent removes the wrong files **through `tc`**, you can find them in Trash and recover them
while they remain there. Ask the Agent to call `tc` explicitly; a terminal alias alone does not cover
all Agent commands. For example, add this instruction to your project’s `AGENTS.md`:

```text
Use tc instead of rm to remove files. For unattended operations, use:
tc --json --non-interactive --confirm=never -- <paths>
```

This covers removals performed through `tc`; direct deletion APIs and file overwrites are outside its scope.

### Keep Finder’s “Put Back” available

Moving an item to Trash does not always preserve Finder’s “Put Back” action. We fixed reproduced
cases involving a restored file immediately moved to Trash again, and symbolic links moved through
system Trash APIs. The fix applies to items moved by `tc`.

[Local macOS acceptance checks](docs/release-acceptance-v0.1.0.md#finder-recovery-evidence) confirm
these recovery cases. Put Back is not guaranteed on every volume or after every failure.

## Command reference

```text
Usage:
  tc [OPTIONS] [--] <PATH>...
  tc --help [-a] [-zh]
  tc --version

Confirmation:
  -f, --force             Never prompt; ignore missing paths
  -i, --interactive       Confirm each input
  -I                      Confirm once for >3 inputs or any directory
      --confirm=<MODE>    Choose a confirmation policy:
                            smart  Ask once for multiple inputs or any directory (default)
                            never  Never prompt
                            once   Ask once for the batch
                            each   Ask before each input

Operation:
      --dry-run           Preview without moving anything
      --ignore-missing    Ignore missing paths without changing confirmation policy
      --non-interactive   Fail if a confirmation prompt would be needed
      --stop-on-error     Stop after the first item failure; skip remaining inputs
      --strict-options    Reject no-effect compatibility options, including -P
  --                      End option parsing (for paths beginning with a hyphen)

Output:
  -v, --verbose           Show every top-level result
      --quiet             Suppress normal output; retain warnings and errors
      --json              Write one JSON document to stdout; diagnostics stay on stderr

Information:
      --help              Show native help
  -a                      With --help: show compatibility options
  -zh                     With --help: show Chinese help
      --version           Show the installed version

rm compatibility:
  -r, -R, -d, -x          Accepted with no effect; directories move as whole items
  -P                      Warn that secure overwrite is not performed
  -W                      Unsupported; returns a usage error

Exit codes:
  0  Success (including moved items with warnings)
  1  Operational or safety failure
  64 Invalid options or command usage
```

`--json` and `--quiet` cannot be combined. Operational short options can be grouped, such as `-iv`.
Required confirmation needs a TTY; for scripts, use `--non-interactive --confirm=never`.

## Examples

```sh
tc -i report.txt build/   # Confirm each item
tc -- -leading-hyphen     # A filename starting with -
tc --help -a -zh          # Chinese compatibility help
```

For detailed behavior, see the [help contract](docs/help.md). For contributing, see the
[development guide](docs/development.md) and [contribution guide](CONTRIBUTING.md).

Licensed under [Apache-2.0](LICENSE). See [NOTICE](NOTICE) and the [security policy](SECURITY.md).
