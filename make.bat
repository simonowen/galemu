@echo off

if "%1"=="clean" goto clean

pyz80.py --exportfile=galemu.sym galemu.asm
goto end

:clean
if exist galemu.dsk del galemu.dsk galemu.sym

:end
