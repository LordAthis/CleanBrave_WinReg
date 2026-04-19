# Check-BraveRegistry.ps1 - Biztonsági beállítások validálása
$regUrl = "https://githubusercontent.com"
$tempReg = Join-Path $env:TEMP "check_brave.reg"

Write-Host "--- Brave Registry Ellenőrzés Indítása ---" -ForegroundColor Cyan

try {
    # Letöltés a validáláshoz
    Invoke-WebRequest -Uri $regUrl -OutFile $tempReg -UseBasicParsing
    $regContent = Get-Content $tempReg
    $mismatches = @()
    $currentKey = ""

    foreach ($line in $regContent) {
        $line = $line.Trim()
        if ($line -match "^\[(.*)\]$") {
            $currentKey = $matches[1].Replace("HKEY_LOCAL_MACHINE", "HKLM:").Replace("HKEY_CURRENT_USER", "HKCU:")
        }
        elseif ($line -match "^`"(.+)`"=(.+)$") {
            $name = $matches[1]
            $valRaw = $matches[2]
            
            # Érték konvertálása (dword -> int)
            $expected = if ($valRaw -match "dword:([0-9a-fA-F]+)") { [Convert]::ToInt32($matches[1], 16) } else { $valRaw.Trim('"') }

            try {
                $actual = Get-ItemPropertyValue -Path $currentKey -Name $name -ErrorAction Stop
                if ($actual -ne $expected) { $mismatches += "$name (Várt: $expected, Van: $actual)" }
            } catch {
                $mismatches += "$name (Hiányzik az ágból: $currentKey)"
            }
        }
    }

    if ($mismatches.Count -eq 0) {
        Write-Host "[OK] A registry ágak megfeleltek a követelményeknek!" -ForegroundColor Green
    } else {
        Write-Host "[HIBA] Az alábbi eltérések találhatók:" -ForegroundColor Red
        $mismatches | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }
} catch {
    Write-Host "Hiba a letöltés vagy ellenőrzés során!" -ForegroundColor Red
} finally {
    if (Test-Path $tempReg) { Remove-Item $tempReg -Force }
}
