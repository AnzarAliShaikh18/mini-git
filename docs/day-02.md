# Day 2 - Reading, hashing, object storage, and staging

## My learning summary

I extended Mini Git from repository initialization to `minigit add <file>`.
I learned how to read a file, calculate a content hash, store its bytes as an
object, and record the filename and hash in a staging index.

I worked through these ideas step by step in the **Plan Mini Git Project**
conversation. This journal describes the saved Day 2 code; the code was kept
unchanged during the documentation and GitHub update.

## How the lesson progressed

1. **Read a file.** I used `std::ifstream`, `std::getline`, and a `while` loop
   in `practice.cpp`. The program opened its own source file, which explained
   why its output was C++ code.
2. **Extend the command line.** I kept `init` and added `add <file>`. Each
   command checks its own argument count: `init` needs two arguments including
   the executable name; `add` needs three.
3. **Hash the contents.** I added `hashContent()` with 64-bit FNV-1a and formatted
   the result as 16 hexadecimal characters. In the conversation I reported two
   different hashes after changing `hellow.txt`: `1b0d9eaa85151d5a` and
   `f94eb4e485af821b`.
4. **Preserve the exact bytes.** The final code reads with `std::ios::binary`,
   `file.get(byte)`, and `content.push_back(byte)`. This avoids reconstructing
   lines and accidentally changing newline bytes.
5. **Store objects.** The content is written to `.minigit/objects/<hash>`.
   Existing object paths are reused.
6. **Update the staging index.** `stageFile()` reads the existing mappings into
   a map, adds or replaces the requested filename, and writes the index back.

## What the code does now

```text
add <file>
    -> check repository and file
    -> read exact bytes
    -> calculate content hash
    -> store object if absent
    -> update filename-to-hash mapping in .minigit/index
```

| Function | Responsibility |
| --- | --- |
| `initRepository()` | Creates the Day 1 repository structure. |
| `hashContent(content)` | Returns a 16-character FNV-1a content ID. |
| `stageFile(filePath, hash)` | Reads, updates, and saves the staging index. |
| `addfile(filePath)` | Reads the file, stores its object, and stages it. |
| `main(argc, argv)` | Validates and dispatches `init` and `add`. |

The working file can change after it is staged. The index still points to the
stored version until I add that filename again. Adding another filename with the
same bytes reuses the object but must still create its own index entry.

## Important correction during the lesson

An intermediate version returned early when an object already existed and did
not connect object storage to `stageFile()`. The saved final version only skips
the object-writing step, then always calls `stageFile(filePath, hash)`.
This matters when two filenames have identical contents or an existing object
needs to be staged again.

## New C++ topics

| Topic | What I used it for |
| --- | --- |
| `std::ifstream`, `std::getline` | Practising file input line by line. |
| `std::ios::binary`, `get()`, `push_back()` | Reading and collecting the actual file bytes. |
| `const std::string&` | Passing a string by reference without changing it. |
| `uint64_t`, `ULL` | Representing the 64-bit hash and its constants. |
| Range-based `for`, `unsigned char` | Processing each byte for hashing. |
| `^=`, `*=` | XOR and multiplication in the FNV-1a calculation. |
| `std::stringstream`, `std::hex` | Converting the hash number to hexadecimal text. |
| `std::setw(16)`, `std::setfill('0')` | Keeping hash strings 16 characters wide. |
| `fs::path` and `/` | Joining the object directory and hash filename. |
| `std::map<std::string, std::string>` | Keeping one hash per supplied filename. |
| `std::quoted` | Reading and writing filenames that contain spaces. |
| `const auto&`, `entry.first`, `entry.second` | Iterating through map keys and values. |
| `bad()`, `eof()`, stream checks | Detecting file I/O and parsing problems. |

FNV-1a is a non-cryptographic hash used here for learning. Hashes are not guaranteed
unique; this implementation does not detect collisions.

## Files from Day 2

- `src/main.cpp`: the Mini Git implementation.
- `practice.cpp`: the separate file-reading exercise; it has its own `main()`
  and is intentionally outside `src/` so the normal build does not link it.
- `src/hellow.txt`: the sample file used while learning.
- `README.md`: updated milestone, commands, and project structure.
- `docs/day-02.md`: this learning journal.

Executables and `.minigit/` data remain local and ignored by real Git.

## Try it from the project root

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
.\build\minigit.exe init
.\build\minigit.exe add src/hellow.txt
Get-Content .\.minigit\index
```

An index entry contains a quoted filename followed by its hash. Changing the file
and running `add` again replaces that filename's mapping; old objects remain.

## Verification for this update

The unchanged saved code built successfully with C++17 and warnings enabled.
A separate temporary verification run passed **30 checks**: the existing 14
Day 1 checks plus 16 Day 2 checks. Day 2 covered argument errors, adding before
initialization, missing files, directories, a known FNV-1a value, exact object
contents, index creation, duplicate-content reuse, changed-file staging,
preserving old objects, filenames with spaces, empty files, and binary bytes.

The repository's existing `scripts/test.ps1` still contains the Day 1 checks;
the extra Day 2 verification was run separately without changing project code
or test scripts.

## Current limits and next step

Only single-file `add` and `init` are implemented. There is no commit, log,
checkout, recursive add, staged deletion, or path normalization yet. The index
uses the supplied path spelling, and updates rewrite it directly rather than
using an atomic replacement. This remains a small learning implementation.

Next, review how stored objects and the staging index can become a commit, and
agree on the next small feature before writing Day 3 code.
