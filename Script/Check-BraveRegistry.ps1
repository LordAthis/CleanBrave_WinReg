# Check-BraveRegistry.ps1 - Biztonsági beállítások validálása
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# A REGISZTRÁCIÓS FÁJL PONTOS RAW CÍME:
$regUrl = "https://githubusercontent.com"
$tempReg = Join-Path $env:TEMP "check_brave.reg"

Write-Host "--- Brave Registry Ellenőrzés Indítása ---" -ForegroundColor Cyan

try {
    # Letöltés a pontos címmel
    Invoke-WebRequest -Uri $regUrl -OutFile $tempReg -UseBasicParsing -ErrorAction Stop
    
    $regContent = Get-Content $tempReg -Raw
    if ($regContent -match "\x00") { $regContent = Get-Content $tempReg -Raw -Encoding Unicode }

    $mismatches = @()
    $currentKey = ""

    foreach ($line in ($regContent -split "`r`n")) {
        $line = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("Windows Registry Editor")) { continue }

        if ($line -match "^\[(.*)\]$") {
            $currentKey = $line.TrimStart('[').TrimEnd(']').Replace("HKEY_LOCAL_MACHINE", "HKLM:").Replace("HKEY_CURRENT_USER", "HKCU:")
        }
        elseif ($line -match "^`"(.+)`"=(.+)$") {
            $name = $matches[1]
            $valRaw = $matches[2]
            
            $expected = if ($valRaw -match "dword:([0-9a-fA-F]+)") { 
                [Convert]::ToInt32($matches[1], 16) 
            } else { 
                $valRaw.Trim('"') 
            }

            try {
                if (-not (Test-Path $currentKey)) {
                    $mismatches += "HIÁNYZIK AZ ÁG: $currentKey"
                    continue
                }
                $actual = Get-ItemPropertyValue -Path $currentKey -Name $name -ErrorAction Stop
                if ($actual -ne $expected) { 
                    $mismatches += "$name (Várt: $expected, Van: $actual)" 
                }
            } catch {
                $mismatches += "$name (Nincs beállítva)"
            }
        }
    }

    if ($mismatches.Count -eq 0) {
        Write-Host "[OK] A registry ágak megfeleltek a követelményeknek!" -ForegroundColor Green
    } else {
        Write-Host "[!] Az alábbi eltérések találhatók:" -ForegroundColor Red
        $mismatches | Select-Object -Unique | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }

} catch {
    Write-Host "HIBA: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (Test-Path $tempReg) { Remove-Item $tempReg -Force -ErrorAction SilentlyContinue }
}
