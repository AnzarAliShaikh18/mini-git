# Day 1 - Repository initialization

## My learning summary

Today I learned how to use C++17's `std::filesystem` to create folders and nested
directories. I also learned how `argc` and `argv` let a program read command-line
arguments. I used these ideas to implement my first Mini Git command: `init`.

## What I built

- Read the command from `argv[1]` after checking the argument count.
- Created `.minigit/objects` and `.minigit/refs/heads`.
- Used `std::ofstream` to write `ref: refs/heads/main` to `.minigit/HEAD`.
- Checked for an existing repository before creating anything.
- Printed usage instructions or an unknown-command message when needed.

## Concepts to remember

| Code | Meaning |
| --- | --- |
| `namespace fs = std::filesystem;` | A shorter name for the filesystem namespace. |
| `fs::exists(path)` | Checks whether a path exists. |
| `fs::create_directory(path)` | Creates one directory; its parent must exist. |
| `fs::create_directories(path)` | Creates any missing parent directories too. |
| `std::ofstream` | Opens a file for writing. |
| `argc` | Number of arguments, including the program name. |
| `argv` | Array of argument strings; `argv[0]` is the program name. |
| `std::string` | A C++ string used to store and compare the command. |

For `minigit init`, `argc` is `2` and `argv[1]` is `"init"`.
Paths such as `.minigit` are relative to the folder where I run the command.

## Review improvements after Day 1

The setup review added these improvements. They are new material to study, not
features from my original Day 1 commit:

- Corrected the function name to `initRepository` and tidied formatting.
- Changed its return type to `bool`: `true` means success; `false` means failure.
- Used `std::cerr` for errors and exit code `1` for invalid commands or failures.
- Checked file opening and writing, and caught filesystem errors with `try`/`catch`.
- Refused to overwrite a conflicting file or incomplete `.minigit` structure.
- Added build and test scripts, a README, and ignore rules.

`return initRepository() ? 0 : 1;` calls the function, returning `0` if it
succeeds and `1` otherwise. This is the conditional (ternary) operator.

`const fs::filesystem_error& error` receives the exception by reference
without copying or changing it; `what()` gives its error message.
`!` means "not", and `||` means "or". Checking `!headFile` detects a failed
file stream. Directory/file checks verify the expected path types.

## Not implemented yet

Mini Git cannot stage files, store snapshots, create commits, show history, or
switch branches yet. HEAD points to the intended branch, but that branch has no
commit file until commit support is implemented.

## Next step

Build, run the checks, implement the next agreed feature, write a daily summary,
review the diff, then commit and push. Keep each day's work small enough to explain.
