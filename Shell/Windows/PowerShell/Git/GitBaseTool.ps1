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
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string]$Repo,

        [Parameter(Mandatory=$true)]
        [string]$Tag,

        [Parameter(Mandatory=$true)]
        [string]$Token,

        [Parameter(Mandatory=$false)]
        [string]$Title
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