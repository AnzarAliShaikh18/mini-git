#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <cstdint>
#include <sstream>
#include <iomanip>
#include <map>
#include <ctime>
#include <set>

namespace fs = std::filesystem;

bool initRepository()
{
    if (fs::exists(".minigit"))
    {
        // Preserve existing repositories and unrelated files.
        if (!fs::is_directory(".minigit") ||
            !fs::is_directory(".minigit/objects") ||
            !fs::is_directory(".minigit/refs/heads") ||
            !fs::is_regular_file(".minigit/HEAD"))
        {
            std::cerr << "Error: .minigit exists but its repository structure is incomplete.\n"
                      << "Inspect it before trying again; no files were changed.\n";
            return false;
        }

        std::cout << "Mini Git repository already exists.\n";
        return true;
    }

    fs::create_directory(".minigit");
    fs::create_directory(".minigit/objects");
    fs::create_directories(".minigit/refs/heads");

    std::ofstream headFile(".minigit/HEAD");
    if (!headFile)
    {
        std::cerr << "Error: could not open .minigit/HEAD for writing.\n";
        return false;
    }
    headFile << "ref: refs/heads/main\n";
    headFile.close();
    if (!headFile)
    {
        std::cerr << "Error: could not finish writing .minigit/HEAD.\n";
        return false;
    }

    std::cout << "Initialized empty Mini Git repository.\n";
    return true;
}
std::string hashContent(const std::string& content)
{
    uint64_t hash = 14695981039346656037ULL;

    for (unsigned char c : content)
    {
        hash ^= c;
        hash *= 1099511628211ULL;
    }

    std::stringstream stream;

    stream << std::hex
           << std::setw(16)
           << std::setfill('0')
           << hash;

    return stream.str();
}
bool readIndex(std::map<std::string, std::string>& staged);

bool stageFile(
    const std::string& filePath,
    const std::string& hash
)
{
    std::map<std::string, std::string> staged;

    fs::path indexPath = ".minigit/index";

    // Read previously staged files.

    if (fs::exists(indexPath) && !readIndex(staged))
        return false;
    // Add or update the requested file.

    staged[filePath] = hash;

    // Write the updated index.

    std::ofstream output(indexPath);

    if (!output)
    {
        std::cerr << "Could not write index.\n";
        return false;
    }

    for (const auto& entry : staged)
    {
        output << std::quoted(entry.first)
               << " " << entry.second << "\n";
    }

    output.close();

    if (!output)
    {
        std::cerr << "Failed to save index.\n";
        return false;
    }

    return true;
}
bool addfile(const std::string& filePath)
{
    // Step 1: Check if Mini Git has been initialized.

    if (!fs::is_directory(".minigit/objects"))
    {
        std::cerr << "Error: run minigit init first.\n";
        return false;
    }

    // Step 2: Check if the file exists.

    if (!fs::is_regular_file(filePath))
    {
        std::cerr << "Error: file does not exist.\n";
        return false;
    }

    // Step 3: Open the file in binary mode.

    std::ifstream file(filePath, std::ios::binary);

    if (!file)
    {
        std::cerr << "Error: could not open file.\n";
        return false;
    }

    // Step 4: Read the complete file.

    std::string content;
    char byte;

    while (file.get(byte))
    {
        content.push_back(byte);
    }

    if (file.bad())
    {
        std::cerr << "Error: could not read file.\n";
        return false;
    }

    file.close();

    // Step 5: Calculate the hash.

    std::string hash = hashContent(content);

    // Step 6: Determine the object path.

    fs::path objectPath = fs::path(".minigit/objects") / hash;

    // Step 7: Store the object only if it doesn't already exist.

    if (!fs::exists(objectPath))
    {
        std::ofstream objectFile(objectPath, std::ios::binary);

        if (!objectFile)
        {
            std::cerr << "Error: could not create object.\n";
            return false;
        }

        objectFile << content;

        objectFile.close();

        if (!objectFile)
        {
            std::cerr << "Error: could not write object.\n";
            return false;
        }
    }

    // Step 8: Update the staging area.

    if (!stageFile(filePath, hash))
    {
        return false;
    }

    // Step 9: Success!

    std::cout << "Staged: " << filePath << "\n";
    std::cout << "Hash: " << hash << "\n";

    return true;
}
// Day 3: the index holds the complete snapshot for the next commit.
bool isHash(const std::string& value)
{
    return value.size() == 16 &&
           value.find_first_not_of("0123456789abcdef") == std::string::npos;
}

bool readEntries(std::istream& input, std::map<std::string, std::string>& entries)
{
    entries.clear();
    std::string line;
    while (std::getline(input, line))
    {
        if (line.find_first_not_of(" \t\r") == std::string::npos)
            continue;
        std::istringstream row(line);
        std::string name, hash, extra;
        if (!(row >> std::quoted(name) >> hash) || name.empty() ||
            !isHash(hash) || (row >> extra) || !entries.emplace(name, hash).second)
        {
            std::cerr << "Error: invalid entry in staging index or commit.\n";
            return false;
        }
    }
    if (input.bad())
    {
        std::cerr << "Error: could not finish reading entries.\n";
        return false;
    }
    return true;
}

bool readIndex(std::map<std::string, std::string>& staged)
{
    std::ifstream input(".minigit/index");
    if (!input)
    {
        std::cerr << "Error: staging index not found. Run minigit add <file> first.\n";
        return false;
    }
    return readEntries(input, staged);
}

bool checkMainBranch()
{
    if (!fs::is_directory(".minigit/objects") ||
        !fs::is_directory(".minigit/refs/heads"))
    {
        std::cerr << "Error: run minigit init first.\n";
        return false;
    }
    std::ifstream head(".minigit/HEAD");
    std::string reference;
    std::getline(head, reference);
    if (!head || reference != "ref: refs/heads/main")
    {
        std::cerr << "Error: Day 3 supports HEAD pointing to refs/heads/main only.\n";
        return false;
    }
    return true;
}

bool getParentCommit(std::string& parent)
{
    const fs::path branchPath = ".minigit/refs/heads/main";
    if (!fs::exists(branchPath))
    {
        parent = "none";
        return true;
    }
    std::ifstream branch(branchPath);
    std::string extra;
    if (!fs::is_regular_file(branchPath) || !(branch >> parent) ||
        !isHash(parent) || (branch >> extra) || branch.bad())
    {
        std::cerr << "Error: could not read a valid main branch hash.\n";
        return false;
    }
    return true;
}

bool readObject(const std::string& hash, std::string& content)
{
    if (!isHash(hash))
        return false;
    std::ifstream input(fs::path(".minigit/objects") / hash, std::ios::binary);
    if (!input)
    {
        std::cerr << "Error: missing or unreadable object " << hash << ".\n";
        return false;
    }
    std::ostringstream bytes;
    bytes << input.rdbuf();
    content = bytes.str();
    if (input.bad() || hashContent(content) != hash)
    {
        std::cerr << "Error: object contents do not match hash " << hash << ".\n";
        return false;
    }
    return true;
}

struct Commit
{
    std::string message;
    std::string timestamp;
    std::string parent;
    std::map<std::string, std::string> files;
};

bool readCommit(const std::string& hash, Commit& commit)
{
    std::string content;
    if (!readObject(hash, content))
        return false;
    std::istringstream input(content);
    std::string messageLine, timeLine, parentLine, separator;
    if (!std::getline(input, messageLine) || messageLine.rfind("message ", 0) != 0 ||
        !std::getline(input, timeLine) || timeLine.rfind("timestamp ", 0) != 0 ||
        !std::getline(input, parentLine) || parentLine.rfind("parent ", 0) != 0 ||
        !std::getline(input, separator) || !separator.empty())
    {
        std::cerr << "Error: invalid commit object " << hash << ".\n";
        return false;
    }
    commit.message = messageLine.substr(8);
    commit.timestamp = timeLine.substr(10);
    commit.parent = parentLine.substr(7);
    if (commit.message.find_first_not_of(" \t\r\n") == std::string::npos ||
        commit.timestamp.empty() ||
        commit.timestamp.find_first_not_of("0123456789") != std::string::npos ||
        (commit.parent != "none" && !isHash(commit.parent)))
    {
        std::cerr << "Error: invalid commit metadata.\n";
        return false;
    }
    if (!readEntries(input, commit.files) || commit.files.empty())
    {
        std::cerr << "Error: commit must contain a valid file snapshot.\n";
        return false;
    }
    return true;
}

bool commitChanges(const std::string& message)
{
    if (!checkMainBranch())
        return false;
    if (message.find_first_not_of(" \t\r\n") == std::string::npos ||
        message.find_first_of("\r\n") != std::string::npos)
    {
        std::cerr << "Error: commit message must be a nonempty single line.\n";
        return false;
    }
    std::map<std::string, std::string> staged;
    if (!readIndex(staged))
        return false;
    if (staged.empty())
    {
        std::cerr << "Error: nothing to commit.\n";
        return false;
    }

    // Check the saved bytes, not the working files: add chose the snapshot.
    for (const auto& entry : staged)
    {
        std::string content;
        if (!readObject(entry.second, content))
            return false;
    }
    std::string parent;
    if (!getParentCommit(parent))
        return false;
    if (parent != "none")
    {
        Commit previous;
        if (!readCommit(parent, previous))
            return false;
    }

    const std::time_t timestamp = std::time(nullptr);
    if (timestamp == static_cast<std::time_t>(-1))
    {
        std::cerr << "Error: could not obtain the current time.\n";
        return false;
    }
    std::ostringstream data;
    data << "message " << message << "\n"
         << "timestamp " << timestamp << "\n"
         << "parent " << parent << "\n\n";
    for (const auto& entry : staged)
        data << std::quoted(entry.first) << " " << entry.second << "\n";

    const std::string content = data.str();
    const std::string hash = hashContent(content);
    const fs::path objectPath = fs::path(".minigit/objects") / hash;
    if (fs::exists(objectPath))
    {
        std::string existing;
        if (!readObject(hash, existing) || existing != content)
        {
            std::cerr << "Error: conflicting object; no commit saved.\n";
            return false;
        }
    }
    else
    {
        std::ofstream object(objectPath, std::ios::binary);
        object << content;
        object.close();
        if (!object)
        {
            std::cerr << "Error: could not save commit object.\n";
            return false;
        }
    }

    // Publish the new tip only after the complete object has been saved.
    std::ofstream branch(".minigit/refs/heads/main");
    branch << hash << "\n";
    branch.close();
    if (!branch)
    {
        std::cerr << "Error: could not update main branch.\n";
        return false;
    }
    std::cout << "Created commit: " << hash << "\nMessage: " << message << "\n";
    return true;
}

bool showLog()
{
    if (!checkMainBranch())
        return false;
    std::string current;
    if (!getParentCommit(current))
        return false;
    if (current == "none")
    {
        std::cout << "No commits yet.\n";
        return true;
    }
    std::set<std::string> visited;
    while (current != "none")
    {
        if (!visited.insert(current).second)
        {
            std::cerr << "Error: cycle in commit history.\n";
            return false;
        }
        Commit commit;
        if (!readCommit(current, commit))
            return false;
        std::cout << "commit " << current << "\n"
                  << "Timestamp: " << commit.timestamp << "\n"
                  << "Parent: " << commit.parent << "\n"
                  << "Message: " << commit.message << "\n\n";
        current = commit.parent;
    }
    return true;
}

int main(int argc, char* argv[])
{
    if (argc < 2)
    {
        std::cerr << "Usage: minigit <command>\nAvailable commands: init, add, commit, log\n";
        return 1;
    }
    const std::string command = argv[1];
    try
    {
        if (command == "init")
        {
            if (argc != 2)
            {
                std::cerr << "Usage: minigit init\n";
                return 1;
            }
            return initRepository() ? 0 : 1;
        }
        if (command == "add")
        {
            if (argc != 3)
            {
                std::cerr << "Usage: minigit add <file>\n";
                return 1;
            }
            return addfile(argv[2]) ? 0 : 1;
        }
        if (command == "commit")
        {
            if (argc != 4 || std::string(argv[2]) != "-m")
            {
                std::cerr << "Usage: minigit commit -m \"message\"\n";
                return 1;
            }
            return commitChanges(argv[3]) ? 0 : 1;
        }
        if (command == "log")
        {
            if (argc != 2)
            {
                std::cerr << "Usage: minigit log\n";
                return 1;
            }
            return showLog() ? 0 : 1;
        }
        std::cerr << "Unknown command: " << command << "\n";
        return 1;
    }
    catch (const fs::filesystem_error& error)
    {
        std::cerr << "Filesystem error: " << error.what() << "\n";
        return 1;
    }
}
