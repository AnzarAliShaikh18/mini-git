# Mini Git

A small version-control system written in C++17, built one day at a time to learn how Git stores files, stages snapshots, creates commit history, and detects working-directory changes.

**Day 4 complete:** initialize a repository, stage file contents, create commits with timestamps and parent links, display commit history with `log`, and detect modified/deleted files with `status`.

## Quick start on Windows

Open the whole `D:\mini-git` folder in VS Code.

Build from the project root:

```powershell
cd D:\mini-git
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

Or compile directly:

```powershell
g++ src\main.cpp -std=c++17 -o build\minigit.exe
```

Example workflow:

```powershell
.\build\minigit.exe init
.\build\minigit.exe add hello.txt
.\build\minigit.exe status
.\build\minigit.exe commit -m "My first commit"
.\build\minigit.exe log
```

Requirements:

- C++17-capable `g++`
- PowerShell
- Windows setup currently uses MSYS2 UCRT64 GCC

Always run Mini Git from the project root because `.minigit` paths are currently relative to the working directory.

## Project structure

```text
mini-git/
|-- src/
|   `-- main.cpp
|
|-- hello.txt
|
|-- .minigit/                 # Generated locally
|   |-- HEAD
|   |-- index
|   |
|   |-- objects/
|   |   |-- <file-content-hash>
|   |   `-- <commit-hash>
|   |
|   `-- refs/
|       `-- heads/
|           `-- main
|
|-- .vscode/
|-- scripts/
|-- docs/
|-- build/                    # Generated locally
|-- .gitignore
|-- .gitattributes
`-- README.md
```

`build/` and `.minigit/` are ignored by real Git.

The separate `.git/` directory belongs to the actual Git repository used to track the development of this project.

## Mini Git internal structure

### `.minigit/HEAD`

Contains:

```text
ref: refs/heads/main
```

This tells Mini Git that the currently active branch is `main`.

### `.minigit/refs/heads/main`

Contains the hash of the newest commit:

```text
51b6d440d33668c1
```

So the relationship is:

```text
HEAD
 |
 v
refs/heads/main
 |
 v
latest commit
```

### `.minigit/index`

Represents the staging area.

Example:

```text
"hello.txt" e7fe8f5add1063c2
"main.cpp"  91c28a...
```

Meaning:

```text
filename -> staged file-content hash
```

### `.minigit/objects/`

Stores both file-content objects and commit objects.

A file object contains the exact bytes of a staged file.

A commit object contains information such as:

```text
message My first commit
timestamp <Unix timestamp>
parent none

"hello.txt" <file-content-hash>
```

Later commits store the previous commit's hash as their parent.

## Commands

| Command | Behavior |
| --- | --- |
| `init` | Creates `.minigit`, `objects`, `refs/heads`, and symbolic `HEAD`. |
| `add <file>` | Reads exact file bytes, hashes them, stores the object, and updates the staging index. |
| `commit -m "message"` | Creates a commit snapshot from the index and advances `main`. |
| `log` | Walks through parent commit links from newest to oldest. |
| `status` | Compares working files with staged hashes and reports unchanged, modified, or deleted files. |

Example:

```powershell
.\build\minigit.exe add hello.txt
.\build\minigit.exe status
```

Immediately after staging:

```text
hello.txt - unchanged
```

If `hello.txt` is edited without running `add` again:

```text
hello.txt - modified
```

If the file is removed:

```text
hello.txt - deleted
```

Running `add` again updates the staged version.

## How object storage works

When a file is staged:

```text
hello.txt
    |
    v
read exact bytes
    |
    v
FNV-1a hash
    |
    v
.minigit/objects/<hash>
    |
    v
update .minigit/index
```

The hash acts as the object's identifier.

If two files contain identical bytes, they produce the same hash and can reuse the same stored object.

Mini Git currently uses 64-bit FNV-1a for educational simplicity. It is not intended to provide cryptographic collision resistance.

## How commits work

Running:

```powershell
.\build\minigit.exe commit -m "Update hello"
```

causes Mini Git to:

1. Read the staging index.
2. Find the previous commit.
3. Add the commit message and timestamp.
4. Store filename/hash pairs.
5. Hash the complete commit data.
6. Store the commit inside `.minigit/objects/`.
7. Update `.minigit/refs/heads/main`.

Commit history therefore looks like:

```text
HEAD
 |
 v
main
 |
 v
Commit C
 |
 | parent
 v
Commit B
 |
 | parent
 v
Commit A
 |
 v
none
```

A commit refers to file objects rather than storing the same file contents repeatedly.

## How `log` works

`log` begins with the hash stored in:

```text
.minigit/refs/heads/main
```

It reads that commit and then follows its `parent` field repeatedly until:

```text
parent none
```

Example:

```text
commit 51b6d440d33668c1
Timestamp: 1790609520
Parent: c9dcf2ab42b31aca
Message: second commit

commit c9dcf2ab42b31aca
Timestamp: 1790499375
Parent: none
Message: Day 3: save hello snapshot
```

## How `status` works

The staging index contains the hash of the last staged version of each file.

Mini Git hashes the current working file again and compares both hashes:

```text
staged hash == current hash
        |
       yes
        |
   unchanged
```

If they differ:

```text
staged hash != current hash
        |
     modified
```

If the file no longer exists:

```text
deleted
```

This demonstrates one of the main reasons content hashes are useful in version-control systems.

## Current architecture

```text
Working directory
       |
       | minigit add
       v
Staging index
       |
       | minigit commit
       v
Commit object
       |
       +----> file hashes
       |         |
       |         v
       |      objects/
       |
       +----> parent commit
                  |
                  v
             older commit
```

## Learning progress

- Day 1 — Repository initialization and filesystem basics
- Day 2 — File reading, hashing, object storage, and staging index
- Day 3 — Commit objects, timestamps, parent links, and commit history
- Day 4 — `log`, history traversal, and working-directory `status`
- Day 5 — Branches and checkout
- Day 6 — Restore / checkout snapshots and stronger error handling
- Day 7 — Cleanup, testing, documentation, and interview preparation

## Current limitations

Mini Git is an educational project and is not compatible with real Git.

Currently it does not support:

- Multiple branches
- Checkout
- Restoring complete snapshots
- Recursive directory staging
- Staged deletions
- Merge
- Remote repositories
- Crash-atomic index updates
- Cryptographic hashing
- Git object compression
- Parent-directory repository discovery

These limitations are intentional while the core version-control concepts are being built step by step.
