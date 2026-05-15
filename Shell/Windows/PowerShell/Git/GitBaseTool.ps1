function SetGitEncoding{
    git config --global i18n.commitencoding utf-8
    git config --global i18n.logoutputencoding utf-8
    set LESSCHARSET=utf-8
    git config --global core.quotepath false
}

<#
.SYNOPSIS
    將指定路徑下的檔案同步更新至 GitHub Release (支援新增與覆寫)

.DESCRIPTION
    此函式封裝了 GitHub CLI (gh) 的 Release 指令
    會自動檢查指定的 Tag 是否已存在於 GitHub：
    - 若不存在：建立新的 Release 並上傳檔案
    - 若已存在：將檔案上傳至該 Release，若檔案名稱重複則直接覆寫 (Clobber)

.PARAMETER FilePath
    必填。要上傳的檔案路徑。支援單一檔案路徑或萬用字元 (例如: "C:\dist\*.nupkg")

.PARAMETER Repo
    必填。目標 GitHub 存儲庫，格式為 "擁有者/專案名" (例如: "seanhocode/MyTool")

.PARAMETER Tag
    必填。Release 的標籤名稱 (例如: "v1.0.0")

.PARAMETER Token
    必填。用於驗證身分的 GitHub 個人存取權杖 (PAT)

.PARAMETER Title
    選填。建立新 Release 時使用的標題。若未提供，預設與 Tag 相同

.EXAMPLE
    UpdateGitHubRelease -FilePath ".\nupkgs\*.nupkg" -Repo "seanhocode/MyTool" -Tag "v1.0.5" -Token "ghp_xxx"
#>
function UpdateGitHubRelease {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string]$FilePath,

        [Parameter(Mandatory=$true)] [string]$Repo,

        [Parameter(Mandatory=$true)] [string]$Tag,

        [Parameter(Mandatory=$true)] [string]$Token,

        [Parameter(Mandatory=$false)] [string]$Title
    )

    process {
        Write-Host "========================================"
        Write-Host "Syncing Release Assets to: $Repo ($Tag)"

        # 1. 環境準備：檢查 gh cli 是否安裝並設定 Token
        if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
            Write-Error "GitHub CLI (gh) is not installed. Please install it first: winget install --id GitHub.cli --scope user (https://cli.github.com/)"
            return
        }
        $env:GH_TOKEN = $Token

        # 2. 檢查 Release 是否已存在
        # 2>$null 的作用是把可能出現的紅字錯誤訊息隱藏起來，保持畫面乾淨
        gh release view $Tag --repo $Repo 2>$null
        $releaseExists = ($LASTEXITCODE -eq 0)

        if ($releaseExists) {
            # 3a. 如果 Release 已存在，執行 upload 並開啟 --clobber (覆寫)
            Write-Host "Release '$Tag' exists. Uploading/Overwriting assets..."

            $ghArgs = @("release", "upload", "$Tag")
            $ghArgs += "$FilePath"
            $ghArgs += "--repo", "$Repo"
            $ghArgs += "--clobber"

            gh $ghArgs
        } else {
            # 3b. 如果 Release 不存在，執行 create
            Write-Host "Release '$Tag' not found. Creating new release..."
            
            $releaseTitle = if ([string]::IsNullOrWhiteSpace($Title)) { $Tag } else { $Title }
            
            $ghArgs = @("release", "create", "$Tag")
            $ghArgs += "$FilePath"
            $ghArgs += "--repo", "$Repo"
            $ghArgs += "--title", "$releaseTitle"
            $ghArgs += "--notes", "Auto-generated release for version $Tag"

            gh $ghArgs
        }

        # 4. 最後檢查執行狀態
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Release synchronization succeeded."
        } else {
            Write-Error "Release synchronization failed. Exit code: $LASTEXITCODE"
        }
        Write-Host "========================================"
    }
}

<#
.SYNOPSIS
    刪除指定 Git 存儲庫中未追蹤的檔案和目錄

.DESCRIPTION
    此函式封裝了 Git 的 clean 指令，用於刪除未追蹤的檔案和目錄
    -d: 包含刪除未追蹤的目錄
    -f: 強制刪除 (force)
    -x: 包含被 .gitignore 忽略的檔案（例如 bin, obj, 暫存檔）
    --quiet: 減少輸出，增加速度

.PARAMETER RepoPath
    必填。要清理的 Git 存儲庫資料夾路徑

.EXAMPLE
    RemoveGitUntrackedFiles -RepoPath "C:\Projects\MyRepo"
#>
function RemoveGitUntrackedFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string]$RepoPath
    )

    process {
        Push-Location $RepoPath

        # 2. 執行 Git 清理指令
        # -d: 包含刪除未追蹤的目錄
        # -f: 強制刪除 (force)
        # -x: 包含被 .gitignore 忽略的檔案（例如 bin, obj, 暫存檔）
        # --quiet: 減少輸出，增加速度
        git clean -fdx --quiet

        Pop-Location
    }
}

<#
.SYNOPSIS
    克隆指定的 Git 存儲庫

.DESCRIPTION
    此函式封裝了 Git 的 clone 指令，用於克隆指定的 Git 存儲庫

.PARAMETER RepoUrl
    必填。要克隆的 Git 存儲庫 URL

.PARAMETER TargetRootPath
    選填。克隆目標資料夾路徑，若未提供，則使用當前資料夾

.EXAMPLE
    CloneRepository -RepoUrl "https://github.com.tw/seanhocode/Repo1.git" -TargetRootPath "C:\Projects"
#>
function CloneRepository {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] [string]$RepoUrl,
        [Parameter(Mandatory = $false)] [string]$TargetRootPath
    )

    process {
        $pushed = $false
        if (![string]::IsNullOrEmpty($TargetRootPath)) {
            Push-Location $TargetRootPath
            $pushed = $true
        }
        try {
            Write-Host "============================================="
            $repoName = [System.IO.Path]::GetFileNameWithoutExtension($RepoUrl)
        
            if (Test-Path $repoName) {
                Write-Host "Skip [$repoName]: Folder exists."
            } else {
                Write-Host "Downloading [$repoName]..."
                git clone $RepoUrl
            }
            Write-Host "============================================="
        }
        finally { if ($pushed) { Pop-Location } }
    }
}

<#
.SYNOPSIS
    切換指定 Git 存儲庫的分支

.DESCRIPTION
    此函式封裝了 Git 的 checkout 指令，用於切換指定的分支
    並自動處理未提交的變更 (stash)

.PARAMETER RepoPath
    必填。要切換分支的 Git 存儲庫資料夾路徑

.PARAMETER TargetBranch
    必填。目標分支名稱

.EXAMPLE
    SwitchGitBranch -RepoPath "C:\Projects\MyRepo" -TargetBranch "develop"
#>
function SwitchGitBranch {
    [CmdletBinding()]
    param (
        # 接收來自管道的路徑
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] [string]$RepoPath,

        [Parameter(Mandatory = $true)] [string]$TargetBranch
    )

    process {
        # 取得資料夾名稱，方便顯示日誌
        $repoName = [System.IO.Path]::GetFileName($RepoPath)

        # 檢查 .git 資料夾是否存在
        if (-not (Test-Path "$RepoPath\.git")) {
            Write-Host "Skip [$repoName]: Doesn't have .git folder."
            return # 注意：在 process 區塊中要用 return 來跳過當前物件，不能用 continue
        }

        Write-Host "Processing [$repoName] -> Target: $TargetBranch"

        # 切換進資料夾
        Push-Location $RepoPath

        try {
            # 取得目前分支
            # 2>&1 用來攔截可能的錯誤訊息到變數中
            $CurrentBranch = (git rev-parse --abbrev-ref HEAD 2>&1).Trim()
            Write-Host "    Current branch: $CurrentBranch"

            $Stashed = $false
            $HasChanges = git status --porcelain
            if ($HasChanges) {
                Write-Host "    Detected changes. Executing git stash..."
                git stash save "Auto-stash before switching to $TargetBranch" --quiet
                $Stashed = $true
            }

            # 如果不在目標分支，則切換
            if ($CurrentBranch -ne $TargetBranch) {
                Write-Host "    Switching to $TargetBranch..."
                # --quiet:隱藏切換的細節輸出
                git checkout $TargetBranch --quiet 2>&1 | Out-Null
            }

            # 更新分支
            Write-Host "    Fetching & Pulling latest..."
            git fetch origin --quiet
            git pull origin $TargetBranch --quiet

            Write-Host "    Updated to latest state."

            # 恢復 Stash
            if ($Stashed) {
                Write-Host "    Restoring stashed changes..."
                $PopResult = git stash pop --quiet 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "    Stash pop conflict. Please check manually."
                } else {
                    Write-Host "    Stash applied successfully."
                }
            }
        }
        catch {
            Write-Host "    An error occurred: $_"
        }
        finally {
            Pop-Location
        }
    }
}

<#
.SYNOPSIS
    批次克隆多個 Git 存儲庫

.DESCRIPTION
    此函式封裝了多個 Git 存儲庫的克隆操作，並支援並行處理以加快下載速度

.PARAMETER RepoUrlList
    必填。要克隆的 Git 存儲庫 URL 列表

.PARAMETER TargetFolderPath
    必填。克隆目標資料夾路徑

.EXAMPLE
    $RepoUrlList = @(
        "https://github.com.tw/seanhocode/Repo1.git",
        "https://github.com.tw/seanhocode/Repo2.git",
        "https://github.com.tw/seanhocode/Repo3.git",
        "https://github.com.tw/seanhocode/Repo4.git",
        "https://github.com.tw/seanhocode/Repo5.git",
        "https://github.com.tw/seanhocode/Repo6.git"
    )

    BatchClone -RepoUrlList $RepoUrlList -TargetFolderPath "C:\GSS\Radar\Project\Test"
#>
function BatchClone {
    param (
        [Parameter(Mandatory = $true)] [string[]]$RepoUrlList,
        [Parameter(Mandatory = $true)] [string]$TargetFolderPath
    )

    # 取得當前 Session 中 CloneRepository 函式的定義內容
    # 這會將函式代碼封裝成一個 ScriptBlock 變數
    $repoFunc = Get-Item "Function:\CloneRepository"

    if (!(Test-Path $TargetFolderPath)) {
        New-Item -ItemType Directory -Force -Path $TargetFolderPath | Out-Null
        Write-Host "Create target folder: $TargetFolderPath" -ForegroundColor Cyan
    }

    Push-Location $TargetFolderPath
    Write-Host "Starting clone process (Parallel)..." -ForegroundColor Yellow

    $RepoUrlList | ForEach-Object -Parallel {
        # 從外部傳入函式定義並動態建立
        # $using:repoFunc 會把剛才抓到的定義內容傳進來
        $localFunc = [scriptblock]::Create($using:repoFunc.Definition)
        
        # 執行該 ScriptBlock
        $_ | & $localFunc -TargetRootPath $using:TargetFolderPath
    } -ThrottleLimit 5

    Pop-Location
    Write-Host "All downloads done." -ForegroundColor Cyan
}

<#
.SYNOPSIS
    批次切換多個 Git 存儲庫的分支

.DESCRIPTION
    此函式封裝了多個 Git 存儲庫的分支切換操作，並支援並行處理以加快操作速度

.PARAMETER RepoPaths
    必填。要切換分支的 Git 存儲庫資料夾路徑列表

.PARAMETER TargetBranch
    必填。目標分支名稱

.EXAMPLE
    $RepoPaths = @(
        "C:\Project\Repo1",
        "C:\Project\Repo2",
        "C:\Project\Repo3",
        "C:\Project\Repo4",
        "C:\Project\Repo5",
        "C:\Project\Repo6"
    )

    $TargetBranch = "master"

    BatchSwitchBranch -RepoPaths $RepoPaths -TargetBranch $TargetBranch
#>
function BatchSwitchBranch {
    param (
        [Parameter(Mandatory = $true)] [string[]]$RepoPaths,
        [Parameter(Mandatory = $true)] [string]$TargetBranch
    )

    Write-Host ">>> Starting batch branch switch to [$TargetBranch]..." -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Cyan

    # 使用管道將陣列一個個丟給核心邏輯
    $RepoPaths | SwitchGitBranch -TargetBranch $TargetBranch

    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "--- All tasks completed. ---" -ForegroundColor Green
}