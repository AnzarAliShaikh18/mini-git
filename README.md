# Mini Git

A small version-control system built in C++17 to learn how Git works internally,
one feature at a time.

**Current milestone: Day 1 - repository initialization.**
Only `init` is implemented. Staging, snapshots, commits, history, and checkout are
future work. This is a learning project, not a replacement for Git.

## Project layout

```text
mini-git/
|-- src/main.cpp              # Command handling and repository initialization
|-- include/README.md         # Place for future C++ headers
|-- docs/
|   |-- day-01.md             # Day 1 learning journal
|   `-- day-template.md       # Copy this for each new day
|-- scripts/
|   |-- build.ps1             # Build all .cpp files under src
|   `-- test.ps1              # Check Day 1 in a temporary directory
|-- .vscode/
|   |-- settings.json        # Shared project settings
|   `-- tasks.json           # Build and test shortcuts
|-- .gitattributes
|-- .gitignore
`-- README.md
```

Local-only items include `.git/` (real Git history), `build/` (compiled output),
`.minigit/` (this program's data), and `.vscode/c_cpp_properties.json` (local
compiler configuration). The original executable is preserved locally as
`build/legacy-day1.exe`; use the freshly built `build/minigit.exe`.

## Open the project in VS Code

Use **File > Open Folder** and choose the whole `mini-git` folder, not just
`src` or `main.cpp`. On the original Windows setup this is `D:\mini-git`.

- **Ctrl+Shift+E** opens Explorer: the project folders and files.
- **Ctrl+B** toggles the sidebar if it is hidden.
- **Ctrl+Shift+G** opens Source Control: changed files, not the complete file list.
- GitHub shows committed and pushed files. It does not store empty directories;
  `include/README.md` gives the future header folder a useful tracked file.
- Generated files remain visible in Explorer but are ignored by Git. `.git/`
  remains hidden by VS Code's normal defaults; do not edit or delete it.

## Build on Windows

Requirements: a C++17-capable GCC compiler (`g++`) on PATH and PowerShell.
The current machine has TDM-GCC 10.3.0. The Microsoft C/C++ VS Code extension
provides code navigation and diagnostics; the compiler builds the program.

From the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

Or press **Ctrl+Shift+B** in VS Code. This builds all `.cpp` files under `src`
with C++17 and warnings enabled, writing `build/minigit.exe`.
The execution-policy option applies only to this script process; it does not
change the computer's saved policy.

## Run and check Day 1

```powershell
.\build\minigit.exe init
.\build\minigit.exe init
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test.ps1
```

The first `init` creates this in the **current working folder**:

```text
.minigit/
|-- HEAD                      # ref: refs/heads/main
|-- objects/
`-- refs/
    `-- heads/
```

The second `init` reports that the repository already exists and preserves its
contents. No branch commit file is created yet. An existing incomplete structure
or a file named `.minigit` produces an error instead of being overwritten.
Filesystem or write failures return a nonzero exit code; failed initialization
may leave a partial directory that should be inspected manually.

The test script uses its own temporary directory and removes only that directory
afterwards. It checks initialization, HEAD contents, repeated initialization,
invalid arguments, and conflicting or incomplete metadata. In VS Code, use
**Terminal > Run Task > Mini Git: test** to build and test together.

`main` inside `.minigit/HEAD` is the future branch of the toy repository.
The real GitHub project's branch is currently `master`; these are separate.

## My daily workflow

1. Write the day's code under `src/`; add headers under `include/` when needed.
2. Save the files and build with **Ctrl+Shift+B**.
3. Run **Mini Git: test**; add checks for new behavior as the project grows.
4. Copy `docs/day-template.md` to `docs/day-02.md` (or the current day) and
   write what I built, learned, tested, and want to do next.
5. Review and publish the day's source code and notes:

```powershell
git status
git diff
git add src include docs README.md .gitignore .gitattributes scripts .vscode/tasks.json .vscode/settings.json
git diff --cached
git commit -m "Day 2: describe the feature built today"
git push origin master
```

In GitHub Desktop, review **Changes**, enter a short Summary and optional
Description, **Commit to master**, then **Push origin**. A clean Changes list
after committing is normal; the files still exist in the repository.

Source files, documentation, and shared build settings belong on GitHub.
Executables, temporary practice data, and `.minigit/` do not.

## Learning journal

- [Day 1: repository initialization](docs/day-01.md)
- [Daily summary template](docs/day-template.md)

The original Day 1 commits are preserved. The journal expands the original
commit summary and separately labels improvements made during setup review.
