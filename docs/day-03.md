# Day 3 - Saved commits and history

Based on the Day 3 lesson in **Plan Mini Git Project**, the project now moves
past `previewCommit()` to saving real snapshots and traversing their history.

## What changed

1. `readIndex()` loads filename/hash mappings from the staging index.
2. `getParentCommit()` reads `.minigit/refs/heads/main`, or returns `none` for
   the first commit. Invalid branch data fails instead of resetting history.
3. `commitChanges()` builds text containing the message, Unix timestamp,
   parent, and staged file entries. It hashes and stores that text as an object,
   then updates the main branch to the new commit hash.
4. `readCommit()` reads and validates a saved commit.
5. `showLog()` follows parent links and prints newest-to-oldest history.
6. `main()` dispatches init, add, commit, and log.

The old preview function has been replaced. Success now prints
`Created commit: <hash>` and persists the snapshot.

## Storage model

```text
HEAD -> refs/heads/main -> commit object -> parent commit
                              |
                              +-> filename/hash pairs -> file objects
```

HEAD contains `ref: refs/heads/main`. The branch file contains one hash. File
contents and commit text live in `.minigit/objects`. The index remains after
commit so unchanged files stay in the next snapshot.

## Layout cleanup

- `src/main.cpp` is the sole program source.
- `src/hellow.txt` becomes root `hello.txt`, preserving its bytes.
- The earlier practice exercise lives under `docs/examples/`.
- The unused header placeholder becomes `docs/future-headers.md`.
- Old executables and accidental `src/.minigit` data are archived under ignored
  `build/` output instead of being discarded.
- Scripts, VS Code settings, daily notes, and README remain available.

The migration backs up existing data, renames the sample's current index entry,
stages `hello.txt`, and saves a Day 3 demonstration commit at the root. Existing
root objects and history are preserved. Historical commit paths remain historical.

## Run it

```powershell
cd D:\mini-git
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
.\build\minigit.exe init
.\build\minigit.exe add hello.txt
.\build\minigit.exe commit -m "My first commit"
.\build\minigit.exe log
```

Change hello.txt, stage it again, and make a second commit. Its parent must match
the first hash. Editing without staging leaves the saved snapshot unchanged.

Ctrl+Shift+B builds. Terminal > Run Task offers init/add/commit/log, all running
from the project root. F5 configurations use the same executable and prompt for
the add path or commit message. The executable is `build/minigit.exe`.

## C++ concepts

`std::time_t` and `std::time(nullptr)` supply a timestamp. `std::ostringstream`
builds commit text in memory. `std::quoted` preserves spaces in filenames.
`std::map` orders snapshot entries. `std::set` detects repeated hashes while
traversing history. File streams check reads and writes for failures.

## Verification and limits

The warning-enabled C++17 build and **69 automated checks** pass, including
initialization, staging, FNV-1a hashes, first/subsequent commits, parent chains,
retained snapshots, binary/empty files, and errors that must not advance main.
Tests use temporary repositories. The commit object's exact text is rehashed
independently through add; its hash must match the commit hash. Log is tested
over three commits and reports missing or corrupt objects.

This version supports one branch and permits commits without file changes.
It has no checkout, concurrent-writer protection, or crash-atomic writes. Hashes
are non-cryptographic and paths are used as supplied. These remain future steps.
