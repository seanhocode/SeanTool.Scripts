<#
Example:
    $RepoUrlList = @(
        "https://github.com/seanhocode/SeanTool.Scripts.git",
        "https://github.com/seanhocode/SeanTool.CSharp.git",
        "https://github.com/seanhocode/SeanTool.SQL.git"
    )

    BatchClone -RepoUrlList $RepoUrlList -TargetFolderPath $PSScriptRoot

Description:
    批次Clone清單中Repo到指定目錄

ParameterDesc:
    $RepoUrlList
        repo網址清單
        格式:[陣列]

    $TargetFolderPath
        repo上層資料夾
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