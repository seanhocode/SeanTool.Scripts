<#
.SYNOPSIS
    批次複製（Clone）Git 儲存庫至指定目錄

.DESCRIPTION
    1. 檢查並自動建立目標上層資料夾
    2. 切換工作目錄至目標路徑進行作業
    3. 遍歷網址清單，若目標資料夾已存在則跳過，若不存在則執行 git clone
    4. 作業完成後自動返回原工作目錄

.PARAMETER RepoUrlList
    [String[]] Git 儲存庫的網址清單（Array）

.PARAMETER TargetFolderPath
    [String] 儲放所有儲存庫的上層目錄路徑

.EXAMPLE
    $RepoUrlList = @(
        "https://github.com/seanhocode/SeanTool.Scripts.git",
        "https://github.com/seanhocode/SeanTool.CSharp.git"
    )
    BatchClone -RepoUrlList $RepoUrlList -TargetFolderPath "C:\Projects"

.NOTES
    執行此函式前請確保系統已安裝 Git 執行環境
#>
function BatchClone{
    param (
        [Parameter(Mandatory = $true)] [string[]]$RepoUrlList,
        [Parameter(Mandatory = $true)] [string]$TargetFolderPath
    )

    if (!(Test-Path $TargetFolderPath)) {
        New-Item -ItemType Directory -Force -Path $TargetFolderPath
        Write-Host "Create target folder: $TargetFolderPath" -ForegroundColor Cyan
    }

    Push-Location $TargetFolderPath

    Write-Host "Starting clone..." -ForegroundColor Yellow
    Write-Host "=================================================="

    foreach($Url in $RepoUrlList){
        Write-Host "============================================="
        $repoName = [System.IO.Path]::GetFileNameWithoutExtension($url)
    
        if (Test-Path $repoName) {
            Write-Host "Skip [$repoName]: Folder exists." -ForegroundColor Gray
        } else {
            Write-Host "Downloading [$repoName]..." -ForegroundColor Green
            git clone $url
        }
        Write-Host "============================================="
    }

    Pop-Location
    Write-Host "=================================================="
    Write-Host "All downloads done." -ForegroundColor Cyan
}