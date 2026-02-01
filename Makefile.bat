@echo off
chcp 65001
echo ============================================
echo ПРИНУДИТЕЛЬНАЯ СБОРКА WOLFRAM COMPILER
echo ============================================

echo 1. Очистка...
del /f /q wfm.exe 2>nul
del /f /q *.c 2>nul
del /f /q *.obj 2>nul
if exist nimcache rmdir /s /q nimcache

echo 2. Проверка файлов...
dir src\*.nim

echo 3. Компиляция напрямую (минуя nimble)...
nim c --skipUserCfg --skipParentCfg --hints:off --warnings:off --path:. -o:wfm.exe src/main.nim

if %errorlevel% neq 0 (
    echo.
    echo ============================================
    echo ПЕРВАЯ ПОПЫТКА НЕ УДАЛАСЬ
    echo ============================================
    echo.
    echo Пробуем с дебагом...
    nim c --debugInfo --linedir:on --path:. -o:wfm.exe src/main.nim
)

if exist wfm.exe (
    echo.
    echo ============================================
    echo УСПЕХ! Компилятор собран!
    echo ============================================
    echo.
    wfm --version
    echo.
    echo Тест парсера:
    wfm parse example/ex_1/main.w
) else (
    echo.
    echo ============================================
    echo СБОРКА ПРОВАЛЕНА
    echo ============================================
)
pause