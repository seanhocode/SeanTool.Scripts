<#
.SYNOPSIS
    批次將指定的專案編譯並封裝為 NuGet 套件 (.nupkg)

.DESCRIPTION
    針對每一個傳入的專案路徑，會依序執行 Clean (清理)、Build (編譯) 以及 Pack (打包) 動作
    最後會將打包完成的 .nupkg 檔案統一輸出至指定的目標資料夾

.PARAMETER ProjectFullPaths
    包含要打包的專案絕對路徑陣列。可以是包含 .csproj 的資料夾路徑，或是 .csproj 檔案本身的路徑

.PARAMETER TargetFolder
    打包後的 NuGet 套件 (.nupkg) 要輸出的目標資料夾絕對路徑

.EXAMPLE
    $RootPath = Split-Path -Path $PSScriptRoot -Parent
    $TargetDir = Join-Path $RootPath "nupkgs"
    
    # 定義要打包的專案完整路徑
    $ProjectsToPack = @(
        (Join-Path $RootPath "Src\FileTool"),
        (Join-Path $RootPath "Src\JsonTool"),
        (Join-Path $RootPath "Src\ApiTool")
    )

    PackProject -ProjectFullPaths $ProjectsToPack -TargetFolder $TargetDir
#>
function PackProject{
    param (
        [Parameter(Mandatory = $true)] [array]$ProjectFullPaths,
        [Parameter(Mandatory = $true)] [string]$TargetFolder
    )

    # 確保輸出目錄存在，若不存在則自動建立
    if (-not (Test-Path $TargetFolder)) {
        Write-Host "Target folder does not exist. Creating: $TargetFolder" -ForegroundColor DarkGray
        New-Item -ItemType Directory -Path $TargetFolder | Out-Null
    }

    foreach($ProjectFullPath in $ProjectFullPaths) {
        if(Test-Path $ProjectFullPath){
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "Processing Project: $ProjectFullPath" -ForegroundColor Cyan
            
            dotnet clean $ProjectFullPath -c Release
            dotnet build $ProjectFullPath -c Release
            dotnet pack $ProjectFullPath -c Release -o $TargetFolder

            Write-Host "========================================" -ForegroundColor Cyan
        }
        else{
            Write-Host "Project path for $ProjectFullPath does not exist."
        }
    }

    Write-Host "All pack completed." -ForegroundColor Green
}