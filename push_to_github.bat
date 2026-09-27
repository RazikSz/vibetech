@echo off
set "PATH=C:\src\flutter\bin\mingit\cmd;%PATH%"
if "%~1"=="" (
    echo [INFO] Menjalankan git push ke origin firebase...
    git push origin firebase
) else (
    echo [INFO] Menjalankan git push dengan token otentikasi...
    git push https://RazikSz:%~1@github.com/RazikSz/vibetech.git firebase
)
