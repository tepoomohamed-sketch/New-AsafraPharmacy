@echo off
chcp 65001 > nul
title صيدلية عصفرة - خادم الشبكة المحلية

echo.
echo  ╔══════════════════════════════════════════╗
echo  ║      صيدلية عصفرة - خادم الشبكة         ║
echo  ╚══════════════════════════════════════════╝
echo.

:: ── الحصول على عنوان IP المحلي ──
set "LOCAL_IP="
for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr /i "IPv4" ^| findstr /v "169.254"') do (
    if not defined LOCAL_IP (
        set "LOCAL_IP=%%A"
    )
)
:: إزالة المسافة البادئة
if defined LOCAL_IP (
    set "LOCAL_IP=%LOCAL_IP:~1%"
)

set PORT=8080

echo  ✅ الخادم يعمل على المنفذ: %PORT%
echo.
if defined LOCAL_IP (
    echo  ══════════════════════════════════════════════
    echo.
    echo     الرابط لجميع الأجهزة على الواي فاي:
    echo.
    echo        http://%LOCAL_IP%:%PORT%
    echo.
    echo  ══════════════════════════════════════════════
    echo.
    echo  كيفية الاستخدام:
    echo  - من الموبايل: افتح المتصفح واكتب الرابط أعلاه
    echo  - من الكمبيوتر: http://localhost:%PORT%
    echo.
) else (
    echo  ⚠️ تعذّر تحديد عنوان IP تلقائياً
    echo  افتح إعدادات الشبكة وابحث عن "IPv4 Address"
    echo  ثم استخدم: http://[عنوان-IP-الخاص-بك]:%PORT%
    echo.
)
echo  اضغط Ctrl+C لإيقاف الخادم
echo.
echo  ──────────────────────────────────────────────

:: ── محاولة تشغيل Python ──
python --version > nul 2>&1
if %errorlevel% equ 0 (
    echo  [Python] جاري التشغيل...
    python -m http.server %PORT% --bind 0.0.0.0
    goto :end
)

:: ── محاولة py ──
py --version > nul 2>&1
if %errorlevel% equ 0 (
    echo  [Python/py] جاري التشغيل...
    py -m http.server %PORT% --bind 0.0.0.0
    goto :end
)

:: ── محاولة Python3 ──
python3 --version > nul 2>&1
if %errorlevel% equ 0 (
    echo  [Python3] جاري التشغيل...
    python3 -m http.server %PORT% --bind 0.0.0.0
    goto :end
)

:: ── محاولة Node.js ──
node --version > nul 2>&1
if %errorlevel% equ 0 (
    echo  [Node.js] جاري التشغيل...
    npx --yes serve -l %PORT% -s .
    goto :end
)

:: ── إذا لم يُعثر على شيء ──
echo.
echo  ❌ لم يُعثر على Python أو Node.js
echo.
echo  الحلول المتاحة:
echo  ─────────────────────────────────────────────
echo  1) ثبّت Python من: https://python.org/downloads
echo     ✓ حدد خيار "Add Python to PATH"
echo     ثم أعد تشغيل هذا الملف
echo.
echo  2) أو ثبّت Node.js من: https://nodejs.org
echo     ثم أعد تشغيل هذا الملف
echo.
echo  3) أو استخدم امتداد "Live Server" في VS Code
echo  ─────────────────────────────────────────────

:end
echo.
pause
