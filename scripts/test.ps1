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
    Set-Location -LiteralPath $testDirectory
    New-Item -ItemType Directory -Path 'day3' | Out-Null
    Set-Location -LiteralPath 'day3'
    $result = Invoke-MiniGit @('commit', '-m', 'test')
    Assert-Result ($result.Code -ne 0 -and $result.Text.Contains('init first')) 'Commit requires init'
    $result = Invoke-MiniGit @('log')
    Assert-Result ($result.Code -ne 0) 'Log requires init'
    $result = Invoke-MiniGit @('init')
    Assert-Result ($result.Code -eq 0) 'Day 3 repository initializes'
    $result = Invoke-MiniGit @('log')
    Assert-Result ($result.Code -eq 0 -and $result.Text.Contains('No commits yet')) 'Empty history is clear'
    $result = Invoke-MiniGit @('commit', '-m', 'test')
    Assert-Result ($result.Code -ne 0 -and $result.Text.Contains('add <file> first')) 'Commit requires staging'
    foreach ($arguments in @(@('commit'), @('commit','-x','test'), @('log','extra'), @('add'), @('add','missing.txt'))) {
        $result = Invoke-MiniGit $arguments
        Assert-Result ($result.Code -ne 0) ('Invalid command fails: ' + ($arguments -join ' '))
    }

    $dayRoot = (Get-Location).Path
    [IO.File]::WriteAllText((Join-Path $dayRoot 'my notes.txt'), 'hello')
    $result = Invoke-MiniGit @('add', '"my notes.txt"')
    Assert-Result ($result.Code -eq 0 -and $result.Text.Contains('a430d84680aabd0b')) 'Spaces in filename and known FNV-1a hash'
    $blobPath = Join-Path $dayRoot '.minigit/objects/a430d84680aabd0b'
    Assert-Result ([IO.File]::ReadAllText($blobPath) -ceq 'hello') 'Object preserves exact file bytes'
    [IO.File]::WriteAllText((Join-Path $dayRoot 'copy.txt'), 'hello')
    $result = Invoke-MiniGit @('add', 'copy.txt')
    Assert-Result ($result.Code -eq 0 -and @(Get-ChildItem '.minigit/objects').Count -eq 1) 'Duplicate contents reuse object'
    Assert-Result (@(Get-Content '.minigit/index').Count -eq 2) 'Both filenames are staged'
    $indexBefore = Get-Content '.minigit/index' -Raw
    $headBefore = Get-Content '.minigit/HEAD' -Raw
    [IO.File]::WriteAllText((Join-Path $dayRoot 'my notes.txt'), 'changed after staging')
    $result = Invoke-MiniGit @('commit', '-m', '"My first commit"')
    Assert-Result ($result.Code -eq 0 -and $result.Text.Contains('Created commit:')) 'First real commit succeeds'
    $first = (Get-Content '.minigit/refs/heads/main' -Raw).Trim()
    Assert-Result ($first -match '^[0-9a-f]{16}$' -and $result.Text.Contains($first)) 'Main points to printed commit hash'
    $firstText = [IO.File]::ReadAllText((Join-Path $dayRoot ".minigit/objects/$first"))
    Assert-Result ($firstText.StartsWith("message My first commit`n")) 'Commit stores multiword message'
    Assert-Result ($firstText -match '(?m)^timestamp [0-9]+$') 'Commit stores timestamp'
    Assert-Result ($firstText.Contains("parent none`n")) 'First commit has no parent'
    Assert-Result ($firstText.Contains('"my notes.txt" a430d84680aabd0b')) 'Commit uses staged bytes, not changed working file'
    Assert-Result ($firstText.Contains('"copy.txt" a430d84680aabd0b')) 'Commit includes all staged files'
    Assert-Result ((Get-Content '.minigit/index' -Raw) -ceq $indexBefore) 'Commit retains index snapshot'
    Assert-Result ((Get-Content '.minigit/HEAD' -Raw) -ceq $headBefore) 'HEAD stays symbolic'
    [IO.File]::WriteAllText((Join-Path $dayRoot 'commit-copy.txt'), $firstText)
    $result = Invoke-MiniGit @('add', 'commit-copy.txt')
    Assert-Result ($result.Code -eq 0 -and $result.Text.Contains($first)) 'Commit filename hashes the exact serialized bytes'
    [IO.File]::WriteAllText((Join-Path $dayRoot '.minigit/index'), $indexBefore)

    $result = Invoke-MiniGit @('add', '"my notes.txt"')
    Assert-Result ($result.Code -eq 0) 'Changed file stages again'
    $result = Invoke-MiniGit @('commit', '-m', '"Update hello"')
    Assert-Result ($result.Code -eq 0) 'Second commit succeeds'
    $second = (Get-Content '.minigit/refs/heads/main' -Raw).Trim()
    $secondText = [IO.File]::ReadAllText((Join-Path $dayRoot ".minigit/objects/$second"))
    Assert-Result ($second -cne $first) 'Main advances to new commit'
    Assert-Result ($secondText.Contains("parent $first`n")) 'Second commit links to first'
    Assert-Result ([IO.File]::ReadAllText((Join-Path $dayRoot ".minigit/objects/$first")) -ceq $firstText) 'Previous commit preserved'
    Assert-Result ($secondText.Contains('"copy.txt" a430d84680aabd0b')) 'Unchanged files stay in snapshot'
    $result = Invoke-MiniGit @('log')
    Assert-Result ($result.Code -eq 0 -and $result.Text.Contains('My first commit') -and $result.Text.Contains('Update hello')) 'Log traverses both commits'
    Assert-Result ($result.Text.IndexOf($second) -lt $result.Text.IndexOf($first)) 'Log displays newest commit first'

    # Each error must leave the current branch reference unchanged.
    $validIndex = Get-Content '.minigit/index' -Raw
    foreach ($badIndex in @('', '"missing hash.txt"', '"bad.txt" not-a-hash', '"ghost.txt" 0000000000000000', '"a" a430d84680aabd0b extra')) {
        [IO.File]::WriteAllText((Join-Path $dayRoot '.minigit/index'), $badIndex)
        $result = Invoke-MiniGit @('commit', '-m', 'bad')
        Assert-Result ($result.Code -ne 0) 'Invalid or missing staged data rejects commit'
        Assert-Result ((Get-Content '.minigit/refs/heads/main' -Raw).Trim() -ceq $second) 'Failed commit preserves branch'
    }
    [IO.File]::WriteAllText((Join-Path $dayRoot '.minigit/index'), '"incomplete"')
    $result = Invoke-MiniGit @('add', 'copy.txt')
    Assert-Result ($result.Code -ne 0 -and (Get-Content '.minigit/index' -Raw) -ceq '"incomplete"') 'Add preserves malformed index instead of discarding entries'
    [IO.File]::WriteAllText((Join-Path $dayRoot '.minigit/index'), $validIndex)
    $result = Invoke-MiniGit @('commit', '-m', '"   "')
    Assert-Result ($result.Code -ne 0) 'Blank commit message rejected'
    [IO.File]::WriteAllText($blobPath, 'corrupt')
    $result = Invoke-MiniGit @('commit', '-m', 'bad')
    Assert-Result ($result.Code -ne 0 -and $result.Text.Contains('do not match hash')) 'Corrupt staged blob rejected'
    [IO.File]::WriteAllText($blobPath, 'hello')
    [IO.File]::WriteAllText((Join-Path $dayRoot '.minigit/refs/heads/main'), '0000000000000000')
    $result = Invoke-MiniGit @('commit', '-m', 'bad')
    Assert-Result ($result.Code -ne 0) 'Missing parent object rejected'
    $result = Invoke-MiniGit @('log')
    Assert-Result ($result.Code -ne 0) 'Log reports missing commit object'
    [IO.File]::WriteAllText((Join-Path $dayRoot '.minigit/refs/heads/main'), 'invalid')
    $result = Invoke-MiniGit @('commit', '-m', 'bad')
    Assert-Result ($result.Code -ne 0 -and (Get-Content '.minigit/refs/heads/main' -Raw) -ceq 'invalid') 'Invalid branch is not silently reset'
    [IO.File]::WriteAllText((Join-Path $dayRoot '.minigit/refs/heads/main'), $second)
    [IO.File]::WriteAllText((Join-Path $dayRoot ".minigit/objects/$second"), 'broken')
    $result = Invoke-MiniGit @('log')
    Assert-Result ($result.Code -ne 0) 'Log detects corrupt commit'
    [IO.File]::WriteAllText((Join-Path $dayRoot ".minigit/objects/$second"), $secondText)
    [IO.File]::WriteAllText((Join-Path $dayRoot '.minigit/HEAD'), 'ref: refs/heads/other')
    $result = Invoke-MiniGit @('commit', '-m', 'bad')
    Assert-Result ($result.Code -ne 0) 'Unsupported HEAD fails without committing to wrong branch'
    [IO.File]::WriteAllText((Join-Path $dayRoot '.minigit/HEAD'), $headBefore)
    Assert-Result ((Get-Content '.minigit/refs/heads/main' -Raw).Trim() -ceq $second) 'All final error cases preserve branch tip'

    [IO.File]::WriteAllBytes((Join-Path $dayRoot 'empty.txt'), [byte[]]@())
    $result = Invoke-MiniGit @('add', 'empty.txt')
    Assert-Result ($result.Code -eq 0 -and $result.Text.Contains('cbf29ce484222325')) 'Empty file hashes and stages'
    [IO.File]::WriteAllBytes((Join-Path $dayRoot 'binary.bin'), [byte[]]@(0,255,13,10,128))
    $result = Invoke-MiniGit @('add', 'binary.bin')
    Assert-Result ($result.Code -eq 0) 'Binary file stages'
    $result = Invoke-MiniGit @('commit', '-m', '"Binary and empty files"')
    Assert-Result ($result.Code -eq 0) 'Commit verifies empty and binary objects'
    $result = Invoke-MiniGit @('log')
    Assert-Result ($result.Code -eq 0 -and ([regex]::Matches($result.Text, '(?m)^commit ')).Count -eq 3) 'Log traverses three commits'
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
