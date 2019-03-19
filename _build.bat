@echo off
set PATH=C:\MFS\cc65\bin;%PATH%
ca65 src\main.asm -I src -l listing.txt -o main.o -g || goto end
ld65 -C mfight.cfg -o mfight.nes -m map.txt -vm main.o --dbgfile mfight.nes.dbg
:end
pause
