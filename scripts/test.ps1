$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$program = Join-Path $projectRoot 'build/minigit.exe'
if (-not (Test-Path -LiteralPath $program)) { throw 'Build Mini Git first.' }
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testDirectory = Join-Path $temporaryRoot ('minigit-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDirectory | Out-Null
$testCount = 0

function Assert-Result([bool]$condition, [string]$description) {
    if (-not $condition) { throw "FAIL: $description" }
    $script:testCount++
    Write-Host "PASS: $description"
}

function Invoke-MiniGit([string[]]$arguments) {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $program
    $startInfo.Arguments = $arguments -join ' '
    $startInfo.WorkingDirectory = (Get-Location).Path
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($startInfo)
    try {
        $output = $process.StandardOutput.ReadToEnd()
        $errors = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        return @{ Code = $process.ExitCode; Text = $output + $errors }
    }
    finally { $process.Dispose() }
}

# Tests run only in a newly created temporary directory.
Push-Location -LiteralPath $testDirectory
try {
    $result = Invoke-MiniGit @()
    Assert-Result ($result.Code -ne 0 -and $result.Text.Contains('Usage:')) 'Missing command reports usage and fails'
    $result = Invoke-MiniGit @('unknown')
    Assert-Result ($result.Code -ne 0 -and $result.Text.Contains('Unknown command:')) 'Unknown command fails'
    $result = Invoke-MiniGit @('init', 'extra')
    Assert-Result ($result.Code -ne 0) 'Extra arguments fail'
    Assert-Result (-not (Test-Path -LiteralPath '.minigit')) 'Invalid commands do not create metadata'

    $result = Invoke-MiniGit @('init')
    Assert-Result ($result.Code -eq 0) 'First init succeeds'
    Assert-Result ((Test-Path -LiteralPath '.minigit/objects' -PathType Container) -and (Test-Path -LiteralPath '.minigit/refs/heads' -PathType Container)) 'Repository directories exist'
    $head = [IO.File]::ReadAllText((Join-Path $testDirectory '.minigit/HEAD'))
    Assert-Result ($head.Replace("`r`n", "`n") -ceq "ref: refs/heads/main`n") 'HEAD points to main'
    Assert-Result (-not (Test-Path -LiteralPath '.minigit/refs/heads/main')) 'No branch commit is invented'

    Set-Content -LiteralPath '.minigit/objects/keep.txt' -Value 'keep this object'
    Set-Content -LiteralPath '.minigit/HEAD' -Value 'ref: refs/heads/custom'
    $result = Invoke-MiniGit @('init')
    Assert-Result ($result.Code -eq 0 -and $result.Text.Contains('already exists')) 'Repeated init succeeds without reinitializing'
    Assert-Result ((Get-Content -LiteralPath '.minigit/HEAD' -Raw).Trim() -ceq 'ref: refs/heads/custom') 'Repeated init preserves HEAD'
    Assert-Result ((Get-Content -LiteralPath '.minigit/objects/keep.txt' -Raw).Trim() -ceq 'keep this object') 'Repeated init preserves objects'

    New-Item -ItemType Directory -Path 'blocked' | Out-Null
    Set-Location -LiteralPath 'blocked'
    Set-Content -LiteralPath '.minigit' -Value 'unrelated file'
    $result = Invoke-MiniGit @('init')
    Assert-Result ($result.Code -ne 0) 'A conflicting .minigit file fails safely'
    Assert-Result ((Get-Content -LiteralPath '.minigit' -Raw).Trim() -ceq 'unrelated file') 'Conflicting file is preserved'

    Set-Location -LiteralPath $testDirectory
    New-Item -ItemType Directory -Path 'incomplete/.minigit' -Force | Out-Null
    Set-Location -LiteralPath 'incomplete'
    $result = Invoke-MiniGit @('init')
    Assert-Result ($result.Code -ne 0 -and $result.Text.Contains('incomplete')) 'Incomplete repository reports a useful error'
    Write-Host "All $testCount checks passed."
}
finally {
    Pop-Location
    $resolvedTestDirectory = [IO.Path]::GetFullPath($testDirectory)
    $safePrefix = $temporaryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedTestDirectory.StartsWith($safePrefix, [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $resolvedTestDirectory) -notmatch '^minigit-test-[0-9a-f]{32}$') {
        throw 'Refusing to clean up a path outside the temporary test directory.'
    }
    Remove-Item -LiteralPath $resolvedTestDirectory -Recurse -Force
}
