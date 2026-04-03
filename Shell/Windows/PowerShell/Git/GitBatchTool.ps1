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

<#
.SYNOPSIS
    批次切換多個 Git 儲存庫的分支並同步更新

.DESCRIPTION
    1. 檢查目標路徑是否為有效的 Git 儲存庫（是否存在 .git 資料夾）
    2. 自動偵測未提交的改動，若有改動則執行 git stash 暫存以確保切換安全
    3. 切換至目標分支（TargetBranch）並執行 git pull 同步遠端最新狀態
    4. 若先前有暫存改動，切換完成後會自動執行 git stash pop 嘗試還原
    5. 包含錯誤處理機制，確保單一 Repo 失敗時不會中斷整個批次流程

.PARAMETER RepoPaths
    [String[]] 需要進行分支切換的 Git 儲存庫本地路徑清單

.PARAMETER TargetBranch
    [String] 目標分支名稱（例如：main、master 或 hotfix）

.EXAMPLE
    $Repos = @("C:\Projects\Api", "C:\Projects\Web")
    BatchSwitchBranch -RepoPaths $Repos -TargetBranch "develop"

.NOTES
    若 git stash pop 發生衝突，程式會顯示警告訊息，此時需手動介入處理衝突
#>
function BatchSwitchBranch{
    param (
        # 需要切換到指定branch的repo
        [Parameter(Mandatory = $true)] [string[]]$RepoPaths,
        # 設定目標分支 (例如: "main" or "master" or "hotfix")
        [Parameter(Mandatory = $true)] [string]$TargetBranch
    )

    foreach ($Path in $RepoPaths) {
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host "`n>>> Start handling folder: $Path" -ForegroundColor Cyan

        # 檢查repo是否存在.git資料夾
        if (-not (Test-Path "$Path\.git")) {
            Write-Host " [Error] This folder doesn't have .git folder, skip..." -ForegroundColor Red
            continue
        }

        # 切換到repo目錄
        Push-Location $Path

        try {
            # 檢查目前分支
            $CurrentBranch = git rev-parse --abbrev-ref HEAD
            Write-Host " Current branch: $CurrentBranch"

            # 檢查是否有未提交的改動
            $Stashed = $false
            $HasChanges = git status --porcelain
            if ($HasChanges) {
                Write-Host " Detected uncommitted changes, executing git stash..." -ForegroundColor Yellow
                git stash save "Auto-stash before switching to $TargetBranch"
                $Stashed = $true
            }

            # 如果不在目標分支，則切換
            if ($CurrentBranch -ne $TargetBranch) {
                Write-Host " Switching to $TargetBranch..." -ForegroundColor Magenta
                git checkout $TargetBranch
            }

            # 更新分支
            Write-Host " Synchronizing with remote updates..." -ForegroundColor Green
            git fetch origin
            git pull origin $TargetBranch

            Write-Host " [Success] $Path has been updated to the latest state." -ForegroundColor Green

            # 恢復 Stash
            if ($Stashed) {
                Write-Host " Restoring your uncommitted changes (git stash pop)..." -ForegroundColor Yellow
                $PopResult = git stash pop 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host " [Warning] Stash pop had conflicts or issues. Please check manually." -ForegroundColor Red
                    Write-Host $PopResult
                } else {
                    Write-Host " [Success] Stash applied successfully." -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Host " [Failure] An error occurred while processing: $_" -ForegroundColor Red
        }
        finally {
            # 返回原始目錄
            Pop-Location
        }
        Write-Host "==================================================" -ForegroundColor Cyan
    }

    Write-Host "`n--- All done. ---" -ForegroundColor Cyan
}