#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

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

int main(int argc, char* argv[])
{
    if (argc != 2)
    {
        std::cerr << "Usage: minigit <command>\nAvailable commands: init\n";
        return 1;
    }

    std::string command = argv[1];
    if (command != "init")
    {
        std::cerr << "Unknown command: " << command << "\n";
        return 1;
    }

    try
    {
        return initRepository() ? 0 : 1;
    }
    catch (const fs::filesystem_error& error)
    {
        std::cerr << "Filesystem error: " << error.what() << "\n";
        return 1;
    }
}
