@ECHO ON
ca65 -I common %1\%1.asm -g %2 %3 %4 %5 %6 %7 %8 %9
ld65 %1\%1.o -C %1\nes.cfg -o %1\%1.nes --dbgfile %1\%1.dbg
@ECHO OFF