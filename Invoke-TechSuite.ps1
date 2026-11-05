#requires -Version 5.1
<#
.SYNOPSIS
Runs a TechSuite procedure without storing a shop credential in source.
.DESCRIPTION
Supply an API key as SecureString or store TechSuiteApiKey in a registered
Microsoft.PowerShell.SecretManagement vault. Obtain an approved executable
SHA256 independently; do not trust a hash supplied by the download itself.
The legacy service requires the API key in an HTTPS query string. Upstream
servers/proxies may log it. No credential is passed to TechSuite's command line.
Original integration: Ian Alexander, RepairTech Inc., January 26, 2017.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [string]$ExpectedSha256,

    [ValidatePattern('^[0-9]+$')]
    [string]$TechId = '7632',

    [ValidateNotNullOrEmpty()]
    [string]$ProcedureName = 'Cleanup',

    [string]$CustomerName = 'CMPTRX, Inc dba ComputeRx - Roger McClelland',

    [System.Security.SecureString]$ApiKey,
    [string]$ApiKeySecretName = 'TechSuiteApiKey',

    [ValidateRange(1, 1440)]
    [int]$TimeoutMinutes = 120,

    [switch]$KeepWorkDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$workDirectory = $null
$process = $null
$client = $null
$handler = $null
$response = $null
$ownsApiKey = $false
$previousProtocol = $null
$stage = 'configuration'

function ConvertTo-TechSuiteArgument([string]$Value) {
    # Reject characters that could escape quoting in Windows process arguments.
    if ($Value -match '["\x00-\x1f]' -or $Value.EndsWith('\')) {
        throw 'Unsupported command argument.'
    }
    return '"' + $Value + '"'
}

try {
    if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
    if (-not $ApiKey) {
        if (-not (Get-Command Get-Secret -ErrorAction SilentlyContinue)) {
            throw 'Provide a SecureString API key or configure SecretManagement.'
        }
        $ApiKey = Get-Secret -Name $ApiKeySecretName -ErrorAction Stop
        $ownsApiKey = $true
    }
    if ($ApiKey -isnot [System.Security.SecureString] -or $ApiKey.Length -eq 0) {
        throw 'The API key must be a nonempty SecureString.'
    }

    $label = $env:COMPUTERNAME
    if ($CustomerName) { $label = '{0} ({1})' -f $CustomerName, $env:COMPUTERNAME }
    $arguments = '--run --procedure {0} --customer {1}' -f `
        (ConvertTo-TechSuiteArgument $ProcedureName), (ConvertTo-TechSuiteArgument $label)

    $stage = 'workspace creation'
    $workDirectory = Join-Path $env:ProgramData ('ComputeRx-TechSuite-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $workDirectory
    # Restrict potentially account-bound downloads, settings, and reports.
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    foreach ($sid in @($currentSid,
        (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')),
        (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')))) {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $workDirectory -AclObject $acl
    $appPath = Join-Path $workDirectory 'TechSuite.exe'

    $stage = 'download'
    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object System.Net.Http.HttpClientHandler
    # Fail closed on redirects; never forward a credential to a new host.
    $handler.AllowAutoRedirect = $false
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromMinutes(5)
    $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $pointer = [IntPtr]::Zero
    $plainKey = $null
    $downloadUri = $null
    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)
        $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        $downloadUri = 'https://repairtechsolutions.com/teches/{0}/download_techsuite_windows_console/?api_key={1}' -f `
            $TechId, [Uri]::EscapeDataString($plainKey)
        $response = $client.GetAsync($downloadUri).GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) { throw 'Download was rejected.' }
        $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        [IO.File]::WriteAllBytes($appPath, $bytes)
        $bytes = $null
    }
    finally {
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
        $plainKey = $null
        $downloadUri = $null
    }

    $stage = 'executable verification'
    if ((Get-FileHash -LiteralPath $appPath -Algorithm SHA256).Hash -ne $ExpectedSha256) {
        throw 'Executable verification failed.'
    }

    $stage = 'procedure execution'
    $process = Start-Process -FilePath $appPath -ArgumentList $arguments `
        -WorkingDirectory $workDirectory -PassThru
    # Retain evidence on timeout rather than delete files under a running tool.
    if (-not $process.WaitForExit($TimeoutMinutes * 60000)) {
        $KeepWorkDirectory = $true
        throw 'Procedure timeout.'
    }
    if ($process.ExitCode -ne 0) {
        $KeepWorkDirectory = $true
        throw 'TechSuite returned a nonzero exit code.'
    }
    Write-Output 'TechSuite completed. Verify report upload in the dashboard before closing the ticket.'
}
catch {
    # Raw HTTP/vault exceptions can contain credentials. Do not emit $_ or URLs.
    throw ('TechSuite failed during {0}. No underlying exception is emitted. See README.md for recovery.' -f $stage)
}
finally {
    if ($response) { $response.Dispose() }
    if ($client) { $client.Dispose() }
    elseif ($handler) { $handler.Dispose() }
    if ($null -ne $previousProtocol) { [Net.ServicePointManager]::SecurityProtocol = $previousProtocol }
    if ($ownsApiKey -and $ApiKey -is [System.Security.SecureString]) { $ApiKey.Dispose() }
    $ApiKey = $null
    if ($workDirectory -and (Test-Path -LiteralPath $workDirectory)) {
        if ($KeepWorkDirectory -or ($process -and -not $process.HasExited)) {
            Write-Warning ('Retained protected TechSuite files: ' + $workDirectory)
        }
        else {
            try { Remove-Item -LiteralPath $workDirectory -Recurse -Force }
            catch { Write-Warning 'Protected TechSuite files require manual cleanup.' }
        }
    }
}
