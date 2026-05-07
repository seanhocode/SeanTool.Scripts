<#
.SYNOPSIS
    取得兩個 Git Log 之間差異檔案清單

.DESCRIPTION
    此函式會比較指定的基礎分支（Base）與目標分支（Target），並回傳變動過的檔案路徑
    輸出的路徑會自動將 Git 的正斜線 (/) 轉換為 Windows 的反斜線 (\)

.PARAMETER Base
    必要的參數。比較的基準，可以是 Branch Name 或 Commit ID

.PARAMETER Target
    選用參數。要比較的目標，若省略，則與當前工作目錄(Working Tree)比對

.PARAMETER Filter
    選用參數。用於過濾特定的目錄或副檔名
    例如："SQL/*" 或 "*.cs"

.PARAMETER RepoPath
    選用參數。Git 儲存庫的路徑，預設為當前腳本所在的目錄

.PARAMETER FormatOutputPath
    是否將輸出路徑的/取代為\

.EXAMPLE
    $files = GetGitDiffFiles -Base "master" -Target "develop" -Filter "Web/*.config" -FormatOutputPath:$false
    # 回傳 develop 分支相對於 master 在 Web 目錄下變動過的 .config 檔案

.NOTES
    函式會自動將 [Console]::OutputEncoding 設為 UTF8，以支援包含中文檔名的路徑
#>
function GetGitDiffFiles{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$Base,
        [Parameter(Mandatory = $false)] [string]$Target,
        [Parameter(Mandatory = $false)] [string]$Filter,
        [Parameter(Mandatory = $false)] [string]$RepoPath,
        [Parameter(Mandatory = $false)] [switch]$FormatOutputPath = $true
    )

    process {
        if ([string]::IsNullOrWhiteSpace($RepoPath)) {
            $RepoPath = $PSScriptRoot
        }

        Push-Location $RepoPath

        # 確保 Git 處理路徑時不進行轉義（解決中文路徑顯示亂碼）
        git config --global core.quotepath false
        # 設定 PowerShell 輸出編碼為 UTF8 以正確處理中文字元
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        # 建立 Git 參數
        # 如果有 Target，使用 Base..Target 語法；若無，則只比對 Base
        $Range = if (-not [string]::IsNullOrWhiteSpace($Target)) { "${Base}..${Target}" } else { $Base }
        $GitArgs = @("diff", $Range, "--name-only")
        
        if (-not [string]::IsNullOrWhiteSpace($Filter)) {
            $gitArgs += "--"
            $gitArgs += $Filter
        }

        # 執行並轉換路徑斜線
        $Files = & git $gitArgs | ForEach-Object { $_ }

        if($FormatOutputPath) { $Files = $Files | ForEach-Object { $_.Replace('/', '\') } }

        Pop-Location

        return $Files
    }
}

<#
.SYNOPSIS
    取得兩個分支之間的 Commit 標題差異

.DESCRIPTION
    此函式會比較指定的來源分支（SourceBranch）與目標分支（TargetBranch），並回傳在來源分支中存在但在目標分支中不存在的 Commit 標題
    排除 Merge Commit

.PARAMETER RepoPath
    必填。Git 儲存庫的路徑

.PARAMETER SourceBranch
    必填。來源分支名稱

.PARAMETER TargetBranch
    必填。目標分支名稱

.EXAMPLE
    GetGitDiffCommitTitle -RepoPath "C:\Projects\MyRepo" -SourceBranch "develop" -TargetBranch "master"
    # 回傳 develop 分支相對於 master 分支的 Commit 標題差異
#>
function GetGitDiffCommitTitle {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string]$RepoPath,
        [Parameter(Mandatory=$true)] [string]$SourceBranch,
        [Parameter(Mandatory=$true)] [string]$TargetBranch
    )

    process {
        Write-Host "======================================================================="
        if (Test-Path $RepoPath) {
            Write-Host "Processing repository at: $RepoPath" -ForegroundColor Green
            Push-Location $RepoPath
            
            <#
            取得兩個分支的 Commit 標題
            --format="%s"：格式化輸出，%s 代表 Subject（Commit 的標題第一行）
            #>
            $Target = git log $TargetBranch --no-merges --format="%s"
            $Source = git log $SourceBranch --no-merges --format="%s"

            <#
            Compare-Object：PowerShell 內建用來比對兩個物件（或陣列）差異的指令
            -ReferenceObject $Target：將 Target 設為「基準參考物（左邊）」
            -DifferenceObject $Source：將 Source 設為「要比對的差異物（右邊）」
            SideIndicator -eq "=>"：在 PowerShell 的比對結果中：
                => 代表這個項目只存在於右邊（也就是我們設定的 $Source）
                <= 代表這個項目只存在於左邊（也就是 $Target）
            #>
            Compare-Object -ReferenceObject $Target -DifferenceObject $Source | Where-Object SideIndicator -eq "=>" | Select-Object -ExpandProperty InputObject
            Pop-Location
        } else {
            Write-Host "Repository path not found: $RepoPath" -ForegroundColor Red
        }
        Write-Host "======================================================================="
    }
}