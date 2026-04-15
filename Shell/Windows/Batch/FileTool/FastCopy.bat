@echo off
set /p source="Enter source folder path: "
set /p target="Enter target folder path: "

set source=%source:"=%
set target=%target:"=%

echo.
echo Copying files, please wait...
echo ========================================================

robocopy "%source%" "%target%" /MT:32 /E /R:3 /W:5 /NP /UNILOG:"CopyLog.txt"

echo ========================================================
echo.
echo Done!
pause