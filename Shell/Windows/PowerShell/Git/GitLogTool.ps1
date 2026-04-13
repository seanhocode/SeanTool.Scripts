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

.PARAMETER FormatOutputPath
    是否將輸出路徑的/取代為\

.EXAMPLE
    $files = GetGitDiffFiles -Base "master" -Target "develop" -Filter "Web/*.config" -FormatOutputPath:$false
    # 回傳 develop 分支相對於 master 在 Web 目錄下變動過的 .config 檔案

.NOTES
    函式會自動將 [Console]::OutputEncoding 設為 UTF8，以支援包含中文檔名的路徑
#>
function GetGitDiffFiles{
    param (
        [Parameter(Mandatory = $true)] [string]$Base,
        [Parameter(Mandatory = $false)] [string]$Target,
        [Parameter(Mandatory = $false)] [string]$Filter,
        [Parameter(Mandatory = $false)] [string]$RepoPath,
        [Parameter(Mandatory = $false)] [switch]$FormatOutputPath = $true
    )
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