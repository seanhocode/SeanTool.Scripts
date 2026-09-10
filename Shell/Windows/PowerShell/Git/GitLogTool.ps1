function Get-GitBranchRange {
    <#
    .SYNOPSIS
        組出兩個 Git 參照（Branch/Tag/Commit）之間的區間表示式

    .DESCRIPTION
        共用的區間字串組合邏輯：若有 Target，回傳 "Base..Target"；若無 Target，僅回傳 Base
        供 git log / git diff 等指令使用

    .PARAMETER Base
        必要的參數。區間起點，可以是 Branch Name、Tag 或 Commit ID

    .PARAMETER Target
        選用參數。區間終點，若省略則僅回傳 Base（代表與當前工作目錄或 HEAD 比對）

    .EXAMPLE
        Get-GitBranchRange -Base "master" -Target "develop"
        # 回傳 "master..develop"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$Base,
        [Parameter(Mandatory = $false)] [string]$Target
    )

    process {
        if (-not [string]::IsNullOrWhiteSpace($Target)) { "${Base}..${Target}" } else { $Base }
    }
}

function Get-GitCommitShaInRange {
    <#
    .SYNOPSIS
        取得兩個 Git 參照之間區間內的 Commit SHA 清單

    .DESCRIPTION
        共用的「找區間 Commit」邏輯：組出 Base..Target 區間後列出所有 Commit SHA（由新到舊）
        若指定 EndDate，會依 Commit 時間過濾掉超過該時間的 Commit
        （因應 rebase 後 Commit 時間可能不連續，改用逐筆比對而非 git log --until）

    .PARAMETER RepoPath
        必要的參數。Git 儲存庫的路徑

    .PARAMETER Base
        必要的參數。區間起點，可以是 Branch Name、Tag 或 Commit ID

    .PARAMETER Target
        選用參數。區間終點，若省略則僅列出 Base 之後的 Commit

    .PARAMETER EndDate
        選用參數。只保留 Commit 時間小於等於此時間的 Commit

    .EXAMPLE
        $ShaList = Get-GitCommitShaInRange -RepoPath "C:\Projects\MyRepo" -Base "master" -Target "develop" -EndDate ([datetime]'2026-08-12 23:59:59')
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$RepoPath,
        [Parameter(Mandatory = $true)] [string]$Base,
        [Parameter(Mandatory = $false)] [string]$Target,
        [Parameter(Mandatory = $false)] [Nullable[datetime]]$EndDate
    )

    process {
        Push-Location $RepoPath
        $Range = Get-GitBranchRange -Base $Base -Target $Target
        $Log = git log $Range --date=format:"%Y-%m-%d %H:%M:%S" --pretty=format:"%H`t%ad"
        Pop-Location

        if ($EndDate) {
            $Log = $Log | Where-Object { $_ -and [datetime]$_.Split("`t")[1] -le $EndDate }
        }

        $Log | ForEach-Object { $_.Split("`t")[0] }
    }
}

function Get-GitCommitSubjectBySha {
    <#
    .SYNOPSIS
        依指定的 Commit SHA 清單取得對應的 Commit 標題（Subject）

    .DESCRIPTION
        用 git log --no-walk 一次查詢多個 SHA 的 Subject，輸出順序與傳入的 Sha 順序一致

    .PARAMETER RepoPath
        必要的參數。Git 儲存庫的路徑

    .PARAMETER Sha
        必要的參數。Commit SHA 清單，通常來自 Get-GitCommitShaInRange 的回傳結果

    .EXAMPLE
        $ShaList = Get-GitCommitShaInRange -RepoPath $RepoPath -Base "master" -Target "develop"
        Get-GitCommitSubjectBySha -RepoPath $RepoPath -Sha $ShaList
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$RepoPath,
        [Parameter(Mandatory = $true)] [string[]]$Sha
    )

    process {
        if (-not $Sha) { return @() }

        # 備份目前的 Console 編碼
        $OriginalEncoding = [Console]::OutputEncoding
        
        try {
            # 強制將編碼設為 UTF-8，以正確接收 Git 輸出的中文
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            
            Push-Location $RepoPath
            git log --no-walk --pretty=format:"%s" $Sha
        }
        finally {
            Pop-Location
            # 執行完畢後還原編碼，避免影響其他腳本
            [Console]::OutputEncoding = $OriginalEncoding
        }
    }
}

function Get-GitDiffFiles {
    <#
    .SYNOPSIS
        依指定的 Commit SHA 清單取得最終有異動的檔案清單（如 TortoiseGit 的 Compare Revisions）

    .DESCRIPTION
        以實際祖先關係（git merge-base --is-ancestor）在 Sha 清單中找出最舊與最新的 Commit，
        取最舊 Commit 的父 Commit 與最新 Commit 做單次 git diff，
        Sha 清單順序不拘；不使用 Commit 時間排序，避免同秒 Commit 或 rebase 導致時間不連續時判斷錯誤，

        須注意:
            1. 因為是比對頭尾兩個 Commit 的最終樹狀態，若某檔案在區間內先異動又被還原，diff 不會列出該檔案
            2. 因是抓最舊與最新 Commit 的差異，如果刪掉中間某個 Commit，該 commit 的異動還是會被算入
    .PARAMETER Sha
        必要的參數。Commit SHA 清單，順序不拘，通常來自 Get-GitCommitShaInRange 的回傳結果

    .PARAMETER Filter
        選用參數。用於過濾特定的目錄或副檔名
        例如："SQL/*" 或 "*.cs"

    .PARAMETER RepoPath
        選用參數。Git 儲存庫的路徑，預設為當前腳本所在的目錄

    .PARAMETER FormatOutputPath
        是否將輸出路徑的/取代為\

    .EXAMPLE
        $ShaList = Get-GitCommitShaInRange -RepoPath $RepoPath -Base "master" -Target "develop"
        $files = Get-GitDiffFiles -Sha $ShaList -RepoPath $RepoPath -FormatOutputPath:$false
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string[]]$Sha,
        [Parameter(Mandatory = $false)] [string]$Filter,
        [Parameter(Mandatory = $false)] [string]$RepoPath,
        [Parameter(Mandatory = $false)] [switch]$FormatOutputPath = $true
    )

    process {
        if (-not $Sha) { return @() }

        if ([string]::IsNullOrWhiteSpace($RepoPath)) {
            $RepoPath = $PSScriptRoot
        }

        Push-Location $RepoPath

        # 確保 Git 處理路徑時不進行轉義（解決中文路徑顯示亂碼）
        git config --global core.quotepath false
        # 設定 PowerShell 輸出編碼為 UTF8 以正確處理中文字元
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        # 用實際祖先關係（而非 Commit 時間）找最舊/最新 Commit
        # Commit 時間可能同秒或因 rebase 不連續，無法可靠排序，改用 git merge-base --is-ancestor 逐一比對
        $Oldest = $Sha[0]
        $Newest = $Sha[0]
        foreach ($s in $Sha) {
            git merge-base --is-ancestor $s $Oldest; if ($LASTEXITCODE -eq 0) { $Oldest = $s }
            git merge-base --is-ancestor $Newest $s; if ($LASTEXITCODE -eq 0) { $Newest = $s }
        }
        $GitArgs = @("diff", "$Oldest^", $Newest, "--name-only")

        if (-not [string]::IsNullOrWhiteSpace($Filter)) {
            $GitArgs += "--"
            $GitArgs += $Filter
        }

        # 執行並轉換路徑斜線
        $Files = & git $GitArgs | ForEach-Object { $_ }

        if($FormatOutputPath) { $Files = $Files | ForEach-Object { $_.Replace('/', '\') } }

        Pop-Location

        return $Files
    }
}

function Get-GitDiffFilesSimple {
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
        $files = Get-GitDiffFilesOld -Base "master" -Target "develop" -Filter "Web/*.config" -FormatOutputPath:$false
        # 回傳 develop 分支相對於 master 在 Web 目錄下變動過的 .config 檔案

    .NOTES
        函式會自動將 [Console]::OutputEncoding 設為 UTF8，以支援包含中文檔名的路徑
    #>
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

function Get-GitDiffFilesExact {
    <#
    .SYNOPSIS
        依指定的 Commit SHA 清單，取得這些 Commit 所異動的檔案清單

    .DESCRIPTION
        採用「單一 Commit 獨立比對後取聯集」的作法

        1. 如果一個連續的 commit 清單中移除了某個中間的 Commit，該 Commit 的異動檔案就不會被列出
        2. 只要異動過的檔案都會被列出: 如果某檔案在指定的 Commit 中被異動過，即使它在後續的 Commit 被改回原本的樣子，它依然會出現在清單中
        3. 無視順序與時間: 不需要排列 Commit 順序，會獨立處理每一筆 SHA

    .PARAMETER Sha
        必要的參數。Commit SHA 清單，順序不拘，通常來自 Get-GitCommitShaInRange 等函數的回傳結果

    .PARAMETER Filter
        選用參數。用於過濾特定的目錄或副檔名
        例如："SQL/*" 或 "*.cs"

    .PARAMETER RepoPath
        選用參數。Git 儲存庫的路徑，預設為當前腳本所在的目錄

    .PARAMETER FormatOutputPath
        是否將輸出路徑的正斜線 (/) 取代為反斜線 (\)，預設為 $true

    .EXAMPLE
        $ShaList = @("CommitA_SHA", "CommitB_SHA", "CommitD_SHA") # 故意跳過 CommitC
        $files = Get-GitDiffFilesExact -Sha $ShaList -RepoPath $RepoPath
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string[]]$Sha,
        [Parameter(Mandatory = $false)] [string]$Filter,
        [Parameter(Mandatory = $false)] [string]$RepoPath,
        [Parameter(Mandatory = $false)] [switch]$FormatOutputPath = $true
    )

    process {
        if (-not $Sha) { return @() }

        if ([string]::IsNullOrWhiteSpace($RepoPath)) {
            $RepoPath = $PSScriptRoot
        }

        # 為了確保切換路徑出錯時能正常復原，使用 try-finally 包覆
        Push-Location $RepoPath
        try {
            # 確保 Git 處理路徑時不進行轉義（解決中文路徑顯示亂碼）
            git config --global core.quotepath false
            # 設定 PowerShell 輸出編碼為 UTF8 以正確處理中文字元
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

            # 將所有 Commit 異動的檔案集中到這個陣列 (利用 PowerShell 迴圈指派效能較佳)
            $AllFiles = foreach ($s in $Sha) {
                
                # git diff-tree 說明:
                # --no-commit-id: 不要輸出 commit SHA，純輸出結果
                # --name-only: 只顯示檔名
                # -r: 遞迴進入子目錄 (否則遇到資料夾異動只會顯示資料夾)
                # 這裡使用底層指令 (plumbing) diff-tree，能最精確且乾淨地抓取單一 commit 異動
                $GitArgs = @("diff-tree", "--no-commit-id", "--name-only", "-r", $s)

                if (-not [string]::IsNullOrWhiteSpace($Filter)) {
                    $GitArgs += "--"
                    $GitArgs += $Filter
                }

                # 執行並回傳該 Commit 的檔案清單
                & git $GitArgs
            }

            # 1. 排除空字串 (避免因某些 commit 沒有符合的異動檔而產生空行)
            # 2. 去除重複檔案 (多個 commit 可能改到同一個檔案，聯集後只需列出一次)
            $UniqueFiles = $AllFiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

            # 依需求轉換路徑斜線
            if ($FormatOutputPath) { 
                $UniqueFiles = $UniqueFiles | ForEach-Object { $_.Replace('/', '\') } 
            }

            return $UniqueFiles
        }
        finally {
            Pop-Location
        }
    }
}

function Get-GitDiffCommitTitle {
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
        Get-GitDiffCommitTitle -RepoPath "C:\Projects\MyRepo" -SourceBranch "develop" -TargetBranch "master"
        # 回傳 develop 分支相對於 master 分支的 Commit 標題差異
    #>
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