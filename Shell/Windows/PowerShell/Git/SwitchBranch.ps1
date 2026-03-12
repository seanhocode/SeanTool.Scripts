<#==========================================
將$RepoPaths路徑的Repo切換到指定Branch
==========================================#>

# =====================================
# 參數
# =====================================
# 需要切換到指定branch的repo
$RepoPaths = @(
    "D:\Project\repo1",
    "D:\Project\repo2"
)

# 設定目標分支 (例如: "main" or "master" or "hotfix")
$TargetBranch = "main"

# =====================================
# 執行
# =====================================
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

Read-Host "Press Enter to exit..."