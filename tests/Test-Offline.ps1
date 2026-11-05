#requires -Version 5.1
# Offline regression checks. No vendor request or endpoint procedure is run.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $root 'Invoke-TechSuite.ps1'
$checked = 0
foreach ($name in @('Invoke-TechSuite.ps1', 'Original', 'Original 2')) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $root $name), [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ('PowerShell syntax error in ' + $name) }
    $literals = $ast.FindAll({ param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left.Extent.Text -match '^\$(api_?key|startup_password)$' -and
        $node.Right.Extent.Text -match '^\s*["''][^"'']+["'']\s*$'
    }, $true)
    if ($literals.Count) { throw ('Embedded credential assignment in ' + $name) }
    $checked++
}

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath, [ref]$tokens, [ref]$errors)
$helper = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'ConvertTo-TechSuiteArgument'
}, $true)
# Load only the pure quoting function, never the downloader/procedure.
. ([scriptblock]::Create($helper.Extent.Text))
if ((ConvertTo-TechSuiteArgument 'Cleanup procedure') -ne '"Cleanup procedure"') {
    throw 'Space-containing argument was not preserved.'
}
foreach ($value in @('bad"quote', "bad`nline", 'bad\')) {
    $rejected = $false
    try { $null = ConvertTo-TechSuiteArgument $value }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'Unsafe argument was accepted.' }
}

$originalOs = $env:OS
try {
    # Force the pre-network guard even when tests run on Windows.
    $env:OS = 'OfflineAudit'
    foreach ($name in @('Invoke-TechSuite.ps1', 'Original', 'Original 2')) {
        $failedSafely = $false
        try {
            if ($name -eq 'Invoke-TechSuite.ps1') {
                & $scriptPath -ExpectedSha256 ('0' * 64)
            }
            else {
                # Extensionless legacy files require a script host/import context.
                $wrapper = [scriptblock]::Create("param([string]`$PSScriptRoot)`n" +
                    [IO.File]::ReadAllText((Join-Path $root $name)))
                & $wrapper $root -ExpectedSha256 ('0' * 64)
            }
        }
        catch {
            $failedSafely = $_.Exception.Message -like 'TechSuite failed during configuration.*'
        }
        if (-not $failedSafely) { throw ('Expected safe configuration failure in ' + $name) }
    }
    $invalidHashRejected = $false
    try { & $scriptPath -ExpectedSha256 'invalid' }
    catch { $invalidHashRejected = $_.Exception.Message -match 'ExpectedSha256' }
    if (-not $invalidHashRejected) { throw 'Invalid executable hash was accepted.' }
}
finally { $env:OS = $originalOs }
Write-Output ('PASS: parsed {0} entry points; credential assignment checks, argument validation, wrapper forwarding, offline guard, and hash validation.' -f $checked)
