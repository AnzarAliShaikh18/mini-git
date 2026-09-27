param(
    [Parameter(Mandatory = $true)][ValidateSet('init', 'add', 'commit', 'log')][string]$Command,
    [string]$FilePath = 'hello.txt',
    [string]$Message = 'Day 3: save staged files'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$program = Join-Path $projectRoot 'build/minigit.exe'
if (-not (Test-Path -LiteralPath $program)) { throw 'Build Mini Git first with Ctrl+Shift+B.' }
Push-Location -LiteralPath $projectRoot
try {
    switch ($Command) {
        'init' { & $program init }
        'log' { & $program log }
        'add' { & $program add $FilePath }
        'commit' { & $program commit -m $Message }
    }
    $result = $LASTEXITCODE
}
finally { Pop-Location }
exit $result
