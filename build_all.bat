@ECHO OFF
FOR /D %%i IN (*) DO (
    IF EXIST "%%i\%%i.asm" (
         CALL build %%i
    )
)