@echo off

set /p source="Enter source zip path (ex. C:\MyZipFile.zip): "
set /p target="Enter target folder path (ex. C:\Output): "

set source=%source:"=%
set target=%target:"=%

echo Unzipping...

:: 檢查目標資料夾是否存在，若不存在則自動建立
if not exist "%target%" mkdir "%target%"

:: -C：指定解壓縮的目的地資料夾（該資料夾必須已經存在）
tar -xf "%source%" -C "%target%"

echo.
echo Done.

pause