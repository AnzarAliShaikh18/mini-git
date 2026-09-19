#include <iostream>
#include <fstream>
#include <filesystem>
#include <string>
int main(){
    std::ifstream file("practice.cpp");
    if(!file){
        std::cerr<<"Error: could not open practice.cpp for reading.";
        return 1;
    }
    std::string line;
    while(std::getline(file,line)){
        std::cout<<line<<"\n";
    }
    file.close();
    return 0;
}
