@echo off

set /p source="Enter source folder path (ex. C:\MyFolderToZip): "
set /p target="Enter target zip path (ex. C:\Output.zip): "

set source=%source:"=%
set target=%target:"=%

echo Zipping folder...

:: 先切換到 Source 後壓縮當下目錄，可避免壓縮檔解開後，裡面包含一長串 C:\Source\... 的多餘路徑，
:: 指令的最尾端加上一個 .，代表當前目錄下的所有東西
tar -acf "%target%" -C "%source%" .

echo.
echo Done.

pause