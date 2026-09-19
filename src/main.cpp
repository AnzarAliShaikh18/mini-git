#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <cstdint>
#include <sstream>
#include <iomanip>
#include<map>

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
bool stageFile(
    const std::string& filePath,
    const std::string& hash
)
{
    std::map<std::string, std::string> staged;

    fs::path indexPath = ".minigit/index";

    // Read previously staged files.

    if (fs::exists(indexPath))
    {
        std::ifstream input(indexPath);

        if (!input)
        {
            std::cerr << "Could not read index.\n";
            return false;
        }

        std::string name;
        std::string savedHash;

        while (input >> std::quoted(name) >> savedHash)
        {
            staged[name] = savedHash;
        }

        if (!input.eof())
        {
            std::cerr << "Could not parse index.\n";
            return false;
        }

        input.close();
    }

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
int main(int argc, char* argv[])
{
    if (argc < 2)
    {
        std::cerr << "Usage: minigit <command>\nAvailable commands: init, add\n";
        return 1;
    }

    std::string command = argv[1];


    try
    {
        if(command=="init"){
            if(argc!=2){
                std::cerr<<"Usage: minigit init";
                return 1;

            }
            return initRepository() ? 0 : 1;

        }
        if(command=="add"){
            if(argc!=3){
                std::cerr << "Usage: minigit add <file>\n";
                return 1;

            }
            std::string filepath = argv[2];
            return addfile (filepath) ?0:1;
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
