$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDirectory = Join-Path $projectRoot 'build'
$compiler = Get-Command g++.exe -ErrorAction SilentlyContinue
if (-not $compiler) {
    throw 'g++ was not found. Add your C++17-capable GCC bin folder to PATH.'
}
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
$sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src') -Filter '*.cpp' -Recurse | ForEach-Object { $_.FullName })
if ($sourceFiles.Count -eq 0) { throw 'No C++ source files were found in src.' }
& $compiler.Source -std=c++17 -Wall -Wextra -Wpedantic -g '-I' (Join-Path $projectRoot 'include') @sourceFiles -o (Join-Path $buildDirectory 'minigit.exe')
if ($LASTEXITCODE -ne 0) { throw 'Build failed. Fix the compiler errors above and try again.' }
Write-Host 'Build passed: build/minigit.exe'
