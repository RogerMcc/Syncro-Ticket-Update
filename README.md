# TechSuite PowerShell integration

`Invoke-TechSuite.ps1` replaces the legacy 2017 integration. `Original` and
`Original 2` are compatibility wrappers. The exposed shop key has been removed
from current source. **Revocation is still required; Git history remains affected.**
Invoke the named `.ps1` script directly. For legacy RMM imports, deploy the named
script beside the wrapper and ensure the script host sets `$PSScriptRoot`.
Pasting a wrapper alone into an RMM editor is not a standalone deployment.

## Run

Use Windows PowerShell 5.1 or PowerShell 7 on Windows, elevated as required by
TechSuite and the protected ProgramData workspace. Review the selected procedure:
the default `Cleanup` can change the endpoint. This repository does not directly
update Syncro tickets; TechSuite's separately configured integration handles reports.

Obtain the approved TechSuite executable's SHA256 through a trusted independent
channel. A hash from the same untrusted download is not an authenticity check.
An app update requires a newly approved hash. Do not bypass verification on failure.

For an interactive run, collect a **newly rotated** shop key without echoing it:

```powershell
$key = Read-Host 'Rotated TechSuite shop API key' -AsSecureString
$approvedHash = Read-Host 'Independently approved TechSuite executable SHA256'
try {
    .\Invoke-TechSuite.ps1 -ExpectedSha256 $approvedHash -ApiKey $key
}
finally {
    $key.Dispose()
    Remove-Variable key -ErrorAction SilentlyContinue
}
```

For unattended RMM execution, configure Microsoft.PowerShell.SecretManagement
and an appropriate registered vault under the **actual execution identity**.
Store `TechSuiteApiKey` as a SecureString; do not put a key in a script variable,
command line, GitHub secret demonstration, ticket, or environment file committed
to Git. Omit `-ApiKey` to retrieve the vault secret. Vault unlocking and access must
work noninteractively for that identity. This repository does not configure vaults.

Other parameters: `-TechId`, `-ProcedureName`, `-CustomerName`,
`-ApiKeySecretName`, `-TimeoutMinutes`, and `-KeepWorkDirectory`.
The legacy tech ID, procedure, and business label defaults are retained.
Customer labels still append the computer name. Do not include quotes, control
characters, or trailing backslashes in procedure/customer arguments.

The old startup password was empty. Startup passwords are deliberately not sent
on the child process command line. If your app requires a startup password, use
the vendor-supported interactive unlock and validate compatibility before rollout.

## Security and operation limits

- The legacy download API requires a key in its HTTPS query. The script never
  prints it, never passes it to TechSuite on the command line, and suppresses raw
  HTTP/vault errors. Authorized upstream servers, TLS inspection systems, memory
  dumps, debugging, or tracing can still expose it. SecureString cannot erase all
  managed-memory copies. Do not enable HTTP tracing or debug credential capture.
- Downloads fail on redirects and non-success responses. A changed vendor endpoint
  requires review; do not forward the key to arbitrary redirect targets.
- The downloaded executable must match the approved SHA256 before execution.
  Files are stored in a unique directory restricted to the current identity,
  SYSTEM, and Administrators. No fixed shared executable path is reused.
- Process waiting uses the launched process object, with a timeout. Timeout or
  nonzero exit retains the protected workspace for diagnosis; the script does
  not kill a running repair. Check for child tools and report upload before
  manually removing retained files. Use `-KeepWorkDirectory` to retain reports
  on success. Success normally removes only this run's workspace.
- No client endpoint, cleanup procedure, vendor authentication request, or key
  validity test was run during the repository audit. Windows runtime and live
  integration testing remain required on a controlled test endpoint.

## Offline checks

Run `pwsh -NoProfile -File .\tests\Test-Offline.ps1` from the repository.
The checks parse all entry points, reject embedded credential assignments,
exercise argument validation and wrapper forwarding, and verify failure before
network/process operations. They do not validate Windows ACLs or the live API.

## Incident response

See `SECURITY.md`. Do not reuse the exposed key, including after source cleanup.
