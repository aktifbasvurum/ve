# BOT BASLATICI - PowerShell 5.1 Uyumlu
$ErrorActionPreference = 'Continue'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "     BOT BASLATICI - HAZIRLANIYOR" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- [1/6] Eski Chrome surecleri temizle ---
Write-Host "[1/6] Eski tarayici surecleri temizleniyor..." -ForegroundColor Yellow
Get-Process -Name "chrome-headless-shell" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# --- [2/6] Visual C++ Redistributable (onnxruntime icin ZORUNLU) ---
Write-Host "[2/6] Visual C++ Runtime kontrol ediliyor..." -ForegroundColor Yellow
$vcInstalled = (Test-Path "$env:SystemRoot\System32\vcruntime140.dll") -and (Test-Path "$env:SystemRoot\System32\msvcp140.dll") -and (Test-Path "$env:SystemRoot\System32\vcruntime140_1.dll")
if (-not $vcInstalled) {
    Write-Host "[BILGI] Visual C++ 2015-2022 Runtime eksik! Otomatik indiriliyor..." -ForegroundColor Yellow
    $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $vcInstaller = "$env:TEMP\vc_redist.x64.exe"
    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($vcUrl, $vcInstaller)
        Write-Host "[BILGI] Visual C++ kuruluyor, lutfen bekleyin..." -ForegroundColor Yellow
        Start-Process -FilePath $vcInstaller -ArgumentList "/install /passive /norestart" -Wait
        Remove-Item $vcInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Visual C++ basariyla kuruldu!" -ForegroundColor Green
    } catch {
        Write-Host "[UYARI] Visual C++ otomatik yuklenemedi: $_" -ForegroundColor Red
    }
} else {
    Write-Host "[OK] Visual C++ Runtime mevcut." -ForegroundColor Green
}

# --- [3/6] Uyumlu Python bul ---
Write-Host "[3/6] Python 3.10 / 3.11 / 3.12 aranıyor..." -ForegroundColor Yellow

$py = $null

$fixedPaths = @(
    "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
    "$env:USERPROFILE\AppData\Local\Programs\Python\Python310\python.exe",
    "C:\Python310\python.exe",
    "C:\Program Files\Python310\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
    "C:\Python311\python.exe",
    "C:\Program Files\Python311\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
    "C:\Python312\python.exe",
    "C:\Program Files\Python312\python.exe"
)

foreach ($p in $fixedPaths) {
    if (Test-Path $p) {
        $py = $p
        Write-Host "[OK] Python bulundu: $py" -ForegroundColor Green
        break
    }
}

# PATH'deki python surum kontrolu
if (-not $py) {
    $pycmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pycmd -ne $null) {
        $pyExe = $pycmd.Source
        $verNum = & python -c "import sys; print(sys.version_info.major*100+sys.version_info.minor)" 2>$null
        $verInt = [int]$verNum
        if ($verInt -ge 310 -and $verInt -le 312) {
            $py = "python"
            Write-Host "[OK] PATH'deki Python uyumlu (kod:$verInt): $pyExe" -ForegroundColor Green
        } else {
            Write-Host "[UYARI] PATH'deki Python (kod:$verInt) uyumsuz. Python 3.10 kurulacak..." -ForegroundColor Red
        }
    }
}

# Hic uyumlu Python yoksa Python 3.10 indir ve kur
if (-not $py) {
    Write-Host "[BILGI] Python 3.10.11 indiriliyor..." -ForegroundColor Yellow
    $installer = "$env:TEMP\python310.exe"
    $url = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($url, $installer)
    } catch {
        Write-Host "[HATA] Python indirilemedi: $_" -ForegroundColor Red
        Read-Host "Cıkmak icin Enter'a basin"
        exit 1
    }

    if (Test-Path $installer) {
        Write-Host "[BILGI] Python 3.10.11 kuruluyor..." -ForegroundColor Yellow
        Start-Process -FilePath $installer -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_pip=1 Include_test=0" -Wait
        Remove-Item $installer -Force -ErrorAction SilentlyContinue

        $py310 = "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe"
        $py310b = "$env:USERPROFILE\AppData\Local\Programs\Python\Python310\python.exe"
        if (Test-Path $py310) {
            $py = $py310
            Write-Host "[OK] Python 3.10 kuruldu: $py" -ForegroundColor Green
        } elseif (Test-Path $py310b) {
            $py = $py310b
            Write-Host "[OK] Python 3.10 kuruldu: $py" -ForegroundColor Green
        } else {
            Write-Host "[HATA] Python 3.10 kurulumu basarisiz!" -ForegroundColor Red
            Read-Host "Cıkmak icin Enter"
            exit 1
        }
    }
}

# --- [4/6] pip guncelleme ---
Write-Host "[4/6] pip guncelleniyor..." -ForegroundColor Yellow
& $py -m pip install --upgrade pip --quiet

# --- [5/6] Kutuphaneler ve OCR kontrolu ---
Write-Host "[5/6] Kutuphaneler kontrol ediliyor..." -ForegroundColor Yellow

# Playwright kontrolu
& $py -c "import playwright" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[BILGI] playwright kuruluyor..." -ForegroundColor Yellow
    & $py -m pip install playwright --quiet
}
Write-Host "[OK] playwright hazir." -ForegroundColor Green

# ddddocr kontrolu
$ocrTest = & $py -c "import ddddocr; ddddocr.DdddOcr(beta=True, show_ad=False)" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[BILGI] ddddocr ve onnxruntime kuruluyor..." -ForegroundColor Yellow
    & $py -m pip install ddddocr --quiet
    $ocrTest2 = & $py -c "import ddddocr; ddddocr.DdddOcr(beta=True, show_ad=False)" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] ddddocr ve CAPTCHA motoru basariyla hazirlandi!" -ForegroundColor Green
    } else {
        Write-Host "[UYARI] ddddocr yuklendi ama DLL eksik olabilir, Visual C++ calistiriliyor..." -ForegroundColor Yellow
        $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        $vcInstaller = "$env:TEMP\vc_redist.x64.exe"
        try {
            (New-Object System.Net.WebClient).DownloadFile($vcUrl, $vcInstaller)
            Start-Process -FilePath $vcInstaller -ArgumentList "/install /passive /norestart" -Wait
            Remove-Item $vcInstaller -Force -ErrorAction SilentlyContinue
        } catch {}
    }
} else {
    Write-Host "[OK] ddddocr ve CAPTCHA motoru hazir!" -ForegroundColor Green
}

# Chromium tarayici kontrolu
Write-Host "[5.5/6] Chromium tarayicisi kontrol ediliyor..." -ForegroundColor Yellow
& $py -c "from playwright.sync_api import sync_playwright; p=sync_playwright().start(); ok=__import__('pathlib').Path(p.chromium.executable_path).exists(); p.stop(); exit(0 if ok else 1)" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[BILGI] Chromium indiriliyor..." -ForegroundColor Yellow
    & $py -m playwright install chromium
}
Write-Host "[OK] Chromium hazir." -ForegroundColor Green

# --- [6/6] Bot baslat ---
Write-Host ""
Write-Host "[6/6] Bot baslatiliyor..." -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

& $py halk.py

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Bot sonlandi." -ForegroundColor Yellow
Get-Process -Name "chrome-headless-shell" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Read-Host "Cıkmak icin Enter'a basin"
