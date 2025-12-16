# Get-HardwareKeysOnly.ps1

A small PowerShell script that enumerates Microsoft Entra ID users and lists FIDO2 authentication methods while attempting to filter and show only hardware FIDO2 keys (for example, YubiKey or USB/NFC keys) and exclude platform authenticators (phone-based passkeys / Microsoft Authenticator).

The script:
- Connects to Microsoft Graph (using Microsoft.Graph PowerShell SDK)
- Retrieves all users
- Retrieves each user's FIDO2 authentication methods
- Filters out known platform authenticators and flags likely hardware keys
- Displays results to the console and exports them to a timestamped CSV

---

## Files
- Get-HardwareKeysOnly.ps1 — the main script

---

## Prerequisites

- PowerShell 7.x or Windows PowerShell 5.1 (PowerShell 7+ recommended)
- Microsoft Graph PowerShell SDK installed:
  - Install with: `Install-Module Microsoft.Graph -Scope CurrentUser -Force`
- Appropriate Microsoft Entra (formerly Azure AD) Graph permissions and admin consent:
  - Delegated permissions (interactive sign-in): `User.Read.All`, `UserAuthenticationMethod.Read.All`
  - Application permissions (automation/non-interactive) require admin consent and verification that the Graph endpoints used support app-only access. Some authentication-method endpoints may not be available app-only.

- An account with permissions to read users and authentication methods (admin consent typically required).

---

## Usage

1. Save the script as `Get-HardwareKeysOnly.ps1`.

2. Option A — Interactive (delegated) login (recommended for one-off runs):
   - The script contains:
     `Connect-MgGraph -Scopes "User.Read.All", "UserAuthenticationMethod.Read.All" -NoWelcome`
   - Run the script:
     `.\Get-HardwareKeysOnly.ps1`
   - Complete the interactive sign-in and consent if prompted.

3. Option B — Non-interactive / Automation (app-only)
   - Register an app in Microsoft Entra ID, grant the required application permissions, and grant admin consent.
   - Connect using a certificate or client secret:
     `Connect-MgGraph -ClientId <app-id> -TenantId <tenant-id> -CertificateThumbprint <thumbprint>`
   - Verify that the Graph endpoints used in the script support app-only authentication in your tenant before using this approach.

4. Output:
   - Console table of the found keys.
   - A CSV file exported to the current folder named like `HardwareFIDO2Keys_YYYYMMDD_HHmmss.csv`.

---

## What the script does (logic / heuristics)

- For each user:
  - Calls `Get-MgUserAuthenticationFido2Method -UserId <id>` to list FIDO2 methods.
  - Determines whether a method is a platform authenticator (excluded) by checking `$method.Model` and `$method.DisplayName` for values such as:
    - Microsoft Authenticator
    - Authenticator - iOS / Authenticator - Android
    - PhonePassKey
  - Attempts to identify hardware keys by checking:
    - `$method.Model` or `$method.DisplayName` containing `YubiKey`, `USB`, `NFC`
    - Or a non-empty model that is not `Microsoft Authenticator`
  - If a method is not a platform authenticator, it is added to results and flagged (`IsConfirmedHardware`) true/false based on the hardware heuristics.

Notes:
- The heuristics are conservative and not perfect. Custom or vendor-specific keys may be flagged as unknown even if they are hardware keys.
- You can customize the pattern checks to match device names used in your environment.

---

## CSV output columns

- User — Display name of the user
- UserPrincipalName — user's UPN
- DisplayName — method display name as returned by Graph
- Model — model string from the FIDO2 method object
- AaGuid — AAGUID associated with the key
- AttestationType — attestation type returned by Graph
- CreatedDateTime — when the method was added
- IsConfirmedHardware — boolean flag based on script heuristics
- Id — the FIDO2 method id

---

## Customization

- Exclusion / inclusion patterns
  - Modify the `-like` checks for `$isPlatformAuth` and `$isHardwareKey` to fit vendor strings in your tenant.
- Output location
  - Change `$csvPath` to export CSV to a different folder or filename.
- Scope of users
  - The script uses `Get-MgUser -All`. To limit to a subset (e.g., a group), replace that call with a filtered query or enumerate group members to reduce API calls and runtime.
- Parameters
  - Consider adding parameters for output path, tenant/client connection options, or a filter list of users to make the script reusable in automation.

---

## Troubleshooting

- Permission errors:
  - Ensure admin consent has been granted for `User.Read.All` and `UserAuthenticationMethod.Read.All`.
  - If using app-only, verify the Graph endpoint supports app permissions for authentication methods in your tenant.
- Module not found:
  - Install the Microsoft Graph SDK: `Install-Module Microsoft.Graph -Scope CurrentUser -Force`
- Throttling or long run time:
  - Querying every user can take a while for large tenants. Consider querying a subset of users or adding retry/backoff logic if throttled.
- Errors retrieving FIDO2 methods:
  - Some users may not have FIDO2 data, or API responses may vary. The script catches exceptions and writes an error per user.

---

## Security & Compliance

- The script reads authentication method metadata only — it does not download private key material.
- Protect any exported CSVs as they contain user identifiers and device metadata.
- Use least-privilege principles and restrict who can run the script or read the exported results.

---

## License

MIT — use and modify as you like. Attribution appreciated.

---

If you want, I can:
- Update the script to accept parameters (output folder, Connect-MgGraph options, user filters).
- Tighten or broaden the heuristics to match device strings you see in your tenant (provide sample DisplayName/Model values).
- Produce a ready-to-commit README and/or open a PR with the updated script and README.
