# Check-BraveRegistry.ps1 - Biztonsági beállítások validálása
# Biztonsági protokoll kényszerítése (TLS 1.2) a letöltéshez
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$regUrl = "https://githubusercontent.com"
$tempReg = Join-Path $env:TEMP "check_brave.reg"

Write-Host "--- Brave Registry Ellenőrzés Indítása ---" -ForegroundColor Cyan

try {
    Write-Host "Forrás letöltése: $regUrl" -ForegroundColor Gray
    Invoke-WebRequest -Uri $regUrl -OutFile $tempReg -UseBasicParsing -ErrorAction Stop
    
    # A GitHub reg fájlok gyakran UTF-16 kódolásúak, így olvassuk be
    $regContent = Get-Content $tempReg
    $mismatches = @()
    $currentKey = ""

    foreach ($line in $regContent) {
        $line = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("Windows Registry Editor")) { continue }

        if ($line -match "^\[(.*)\]$") {
            $currentKey = $matches[1].Replace("HKEY_LOCAL_MACHINE", "HKLM:").Replace("HKEY_CURRENT_USER", "HKCU:")
        }
        elseif ($line -match "^`"(.+)`"=(.+)$") {
            $name = $matches[1]
            $valRaw = $matches[2]
            
            # Érték konvertálása (dword -> int)
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
                $mismatches += "$name (Hiányzik a kulcs az ágból)"
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
    Write-Host "Hiba történt: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (Test-Path $tempReg) { Remove-Item $tempReg -Force }
}
