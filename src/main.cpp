#include <iostream>
#include <filesystem>
#include<fstream>
#include <string>

namespace fs =std::filesystem;
void initreprository()
{
    if(fs::exists(".minigit"))
    {
        std::cout<<"Mini Git repositroy already exists";
        return;
    }

    fs::create_directory(".minigit");
    fs::create_directory(".minigit/objects");
    fs::create_directories(".minigit/refs/heads");
    std::ofstream headFile(".minigit/HEAD");
    headFile << "ref: refs/heads/main\n";
    headFile.close();
    std::cout<<"Mini Git repository initialized successfully.\n";
}
int main(int argc, char* argv[])
{
    if (argc < 2)
    {
        std::cout << "Usage: minigit <command>\n";
        return 1;
    }

    std::string command = argv[1];

    if (command == "init")
    {
        initreprository();
    }
    else
    {
        std::cout << "Unknown command: " << command << "\n";
    }

    return 0;
}
