# Mini Git

A small version-control system written in C++17, built one day at a time to
learn how Git stores files and connects snapshots into history.

**Day 3 complete:** initialize a repository, stage file contents, save commits
with timestamps and parent links, and display history with `log`.

## Quick start on Windows

Open the whole `D:\mini-git` folder in VS Code. Save your source and press
**Ctrl+Shift+B** to build. Run these commands from the project root:

```powershell
cd D:\mini-git
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
.\build\minigit.exe init
.\build\minigit.exe add hello.txt
.\build\minigit.exe commit -m "My first commit"
.\build\minigit.exe log
```

Requirements: a C++17-capable `g++` on PATH and PowerShell. This Windows setup
uses MSYS2 UCRT64 GCC. Debugging uses the Microsoft C/C++ extension and
`C:/msys64/ucrt64/bin/gdb.exe`; adjust compiler/debugger paths on another machine.

**Terminal > Run Task > Mini Git: init / add / commit / log** builds first and
runs from the project root. Add and commit prompt for the filename and message.
The same commands are available in **Run and Debug** for F5. Always use
`build/minigit.exe` when running from a terminal.

## Project structure

The core learning example is:

```text
mini-git/
|-- src/
|   `-- main.cpp
|-- hello.txt
`-- .minigit/                 # Generated locally
    |-- HEAD
    |-- index
    |-- objects/
    |   |-- <file-content-hash>
    |   `-- <commit-hash>
    `-- refs/
        `-- heads/
            `-- main
```

`index` appears after the first `add`; `refs/heads/main` appears after the first
successful commit. Hashes are computed from actual content and will differ
from example values in a lesson.

Supporting files remain separate:

```text
.vscode/                     # Build tasks, run/debug configurations, settings
scripts/                     # build.ps1, run.ps1, test.ps1
docs/                        # Daily learning notes
    examples/practice.cpp    # Earlier exercise, excluded from the normal build
build/                       # Generated executable and local migration backups
.gitignore                   # Excludes binaries and Mini Git data from real Git
.gitattributes               # Text and line-ending rules
README.md
```

`src/` contains only program source. `hello.txt` is the tracked sample input.
`build/` and `.minigit/` are ignored. The separate `.git/` directory contains
this project's real Git history and is managed by Git itself.

## Commands

| Command | Behavior |
| --- | --- |
| `init` | Creates objects, refs/heads, and symbolic HEAD; preserves an existing repository. |
| `add <file>` | Reads exact bytes, hashes and stores them, and updates the filename/hash index. |
| `commit -m "message"` | Saves the entire staged snapshot as a commit object and advances main. |
| `log` | Follows parent links from the newest commit to the first. |

Quote filenames containing spaces. Run from the repository root: metadata paths
are relative to the current directory. Running `init` inside `src` would create
a different repository; parent-folder discovery is not implemented.

## How commits work

Commit text is hashed using the same 64-bit FNV-1a helper as file contents, then
stored in `.minigit/objects/<commit-hash>`:

```text
message My first commit
timestamp <Unix timestamp>
parent none

"hello.txt" <file-content-hash>
```

Later commits store the previous commit's hash in `parent`. A commit reads the
index and stored objects, so editing a working file after `add` does not change
the staged version. Run `add` again to stage new contents.

The index remains after a commit and represents the complete next snapshot;
unchanged files stay included. This version permits a new commit without file
changes and does not implement Git's "nothing changed" detection.

```text
HEAD -> refs/heads/main -> newest commit -> parent -> earlier commit
                              |
                              +-> filename/hash entries -> saved file objects
```

Edit and save `hello.txt`, then try a second commit:

```powershell
.\build\minigit.exe add hello.txt
.\build\minigit.exe commit -m "Update hello"
.\build\minigit.exe log
$commitHash = (Get-Content .\.minigit\refs\heads\main -Raw).Trim()
Get-Content ".\.minigit\objects\$commitHash"
```

The second commit's parent points to the first. Log prints newest first.

## Verification

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test.ps1
```

Or run **Mini Git: test** in VS Code to build and test together. The suite passes
**69 checks** covering initialization, known hashes, duplicate object reuse,
spaces in paths/messages, exact staged snapshots, commit hashes, parent links,
three-commit history, empty/binary files, and missing or corrupt data. Tests use
a fresh temporary directory and preserve your real `.minigit` data. The build
enables C++17 and compiler warnings.

## Commit and push Day 3 with real Git

Review the changes before publishing:

```powershell
git status --short
git diff --check
git diff
git add -A
git diff --cached --stat
git commit -m "Day 3: save commits, show history, and organize project"
git push origin master
```

`master` is the current real Git branch; Mini Git's educational branch is `main`.
The update does not commit or push automatically. Confirm staged changes contain
only the intended source, configuration, sample, and documentation.

## Learning notes and limits

- [Day 1: initialization](docs/day-01.md)
- [Day 2: hashing and staging](docs/day-02.md)
- [Day 3: commits and history](docs/day-03.md)
- [Daily journal template](docs/day-template.md)

This learning project is not Git-compatible. FNV-1a is not cryptographic.
Commit/log support only `main`. There is no checkout, branch switching,
recursive add, staged deletion, path normalization, or locking. Index and branch
writes are not crash-atomic. Commit messages must be nonempty single lines;
use ordinary filenames without line breaks. Future work can add crash-safe
updates and checkout while keeping the core model clear.
