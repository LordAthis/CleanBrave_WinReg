# Check-BraveRegistry.ps1 - Biztonsági beállítások validálása

# 1. TLS 1.2 kényszerítése (GitHub-hoz kötelező)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$regUrl = "https://githubusercontent.com"
$tempReg = Join-Path $env:TEMP "check_brave.reg"

Write-Host "--- Brave Registry Ellenőrzés Indítása ---" -ForegroundColor Cyan

try {
    # 2. Letöltés hibakezeléssel
    Invoke-WebRequest -Uri $regUrl -OutFile $tempReg -UseBasicParsing -ErrorAction Stop
    
    # 3. Beolvasás kényszerített kódolással (a .reg fájlok miatt)
    $regContent = Get-Content $tempReg -Encoding Unicode -ErrorAction SilentlyContinue
    if (-not $regContent -or $regContent[0] -notmatch "Windows Registry Editor") {
        $regContent = Get-Content $tempReg -Encoding UTF8
    }

    $mismatches = @()
    $currentKey = ""

    foreach ($line in $regContent) {
        $line = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("Windows Registry Editor")) { continue }

        # Ág keresése
        if ($line -match "^\[(.*)\]$") {
            $currentKey = $matches[1].Replace("HKEY_LOCAL_MACHINE", "HKLM:").Replace("HKEY_CURRENT_USER", "HKCU:")
        }
        # Kulcs-érték pár keresése
        elseif ($line -match "^`"(.+)`"=(.+)$") {
            $name = $matches[1]
            $valRaw = $matches[2]
            
            # Érték konvertálása
            $expected = if ($valRaw -match "dword:([0-9a-fA-F]+)") { 
                [Convert]::ToInt32($matches[1], 16) 
            } else { 
                $valRaw.Trim('"') 
            }

            # Ellenőrzés a Registry-ben
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
                $mismatches += "$name (Nincs beállítva az ágban)"
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
    # Itt most már TÉNYLEG kiírja, mi a baj (pl. hálózati hiba vagy elérés megtagadva)
    Write-Host "HIBA TÖRTÉNT: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (Test-Path $tempReg) { Remove-Item $tempReg -Force -ErrorAction SilentlyContinue }
}
