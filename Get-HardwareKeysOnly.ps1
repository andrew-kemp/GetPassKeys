# Test Hardware FIDO2 Keys Only
# This script tests the improved filtering to show only hardware keys

Connect-MgGraph -Scopes "User.Read.All", "UserAuthenticationMethod.Read.All" -NoWelcome

Write-Host "=== Hardware FIDO2 Key Test ===" -ForegroundColor Cyan
Write-Host "Finding only hardware FIDO2 keys (excluding platform authenticators)..." -ForegroundColor Yellow

$users = Get-MgUser -All -Property "Id,DisplayName,UserPrincipalName"
$hardwareKeys = @()

foreach ($user in $users) {
    Write-Host "Checking: $($user.DisplayName)" -ForegroundColor Gray
    
    # Get FIDO2 methods only (this is where the hardware keys are)
    try {
        $fido2Methods = Get-MgUserAuthenticationFido2Method -UserId $user.Id -ErrorAction SilentlyContinue
        if ($fido2Methods) {
            foreach ($method in $fido2Methods) {
                # Check if this is a platform authenticator (to exclude)
                $isPlatformAuth = (
                    $method.Model -like "*Microsoft Authenticator*" -or
                    $method.DisplayName -like "*Authenticator - iOS*" -or 
                    $method.DisplayName -like "*Authenticator - Android*" -or
                    $method.DisplayName -like "*PhonePassKey*"
                )
                
                # Check if this is a hardware key (to include)
                $isHardwareKey = (
                    $method.Model -like "*YubiKey*" -or
                    $method.DisplayName -like "*YubiKey*" -or
                    $method.DisplayName -like "*USB*" -or
                    $method.DisplayName -like "*NFC*" -or
                    ($method.Model -notlike "*Microsoft Authenticator*" -and $method.Model -ne "")
                )
                
                # Include if it's NOT a platform authenticator
                if (-not $isPlatformAuth) {
                    $hardwareKeys += [PSCustomObject]@{
                        User = $user.DisplayName
                        UserPrincipalName = $user.UserPrincipalName
                        DisplayName = $method.DisplayName
                        Model = $method.Model
                        AaGuid = $method.AaGuid
                        AttestationType = $method.AttestationType
                        CreatedDateTime = $method.CreatedDateTime
                        IsConfirmedHardware = $isHardwareKey
                        Id = $method.Id
                    }
                    
                    $keyType = if ($isHardwareKey) { "HARDWARE" } else { "UNKNOWN" }
                    Write-Host "  [${keyType}] $($method.DisplayName) ($($method.Model))" -ForegroundColor Green
                } else {
                    Write-Host "  [EXCLUDED] $($method.DisplayName) ($($method.Model)) - Platform Authenticator" -ForegroundColor Red
                }
            }
        }
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== HARDWARE FIDO2 KEYS FOUND ===" -ForegroundColor Green
Write-Host "Total hardware keys: $($hardwareKeys.Count)" -ForegroundColor White

if ($hardwareKeys) {
    $hardwareKeys | Format-Table -AutoSize User, DisplayName, Model, AaGuid, IsConfirmedHardware, CreatedDateTime
    
    # Export to CSV
    $csvPath = "HardwareFIDO2Keys_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $hardwareKeys | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Results exported to: $csvPath" -ForegroundColor Cyan
    
    # Summary by confirmed hardware vs unknown
    $confirmedHardware = ($hardwareKeys | Where-Object { $_.IsConfirmedHardware -eq $true }).Count
    $unknownType = ($hardwareKeys | Where-Object { $_.IsConfirmedHardware -eq $false }).Count
    
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "  Confirmed hardware keys (YubiKey, etc.): $confirmedHardware" -ForegroundColor White
    Write-Host "  Unknown/custom keys: $unknownType" -ForegroundColor White
} else {
    Write-Host "No hardware FIDO2 keys found." -ForegroundColor Yellow
}

Disconnect-MgGraph
