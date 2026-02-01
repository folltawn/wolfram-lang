@echo off
echo Building Wolfram Compiler...
echo.
echo Option 1: Build with Nim directly
echo nim c -o:wfm.exe src/main.nim
echo.
echo Option 2: Build with Nimble
echo nimble build
echo.
echo Option 3: Build in release mode
echo nim c -d:release -o:wfm.exe src/main.nim