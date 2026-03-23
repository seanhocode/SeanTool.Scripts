<#
.SYNOPSIS
    以樹狀結構列出指定路徑的資料夾與檔案

.DESCRIPTION
    遞迴函式，會遍歷指定路徑下的所有子目錄與檔案，並使用 ASCII 字元（如 ├──, └──）產生視覺化的樹狀結構

.PARAMETER Path
    要掃描的起始根目錄路徑。預設為當前目錄 "."

.PARAMETER Indent
    遞迴時內部使用的縮排字串，一般調用時不需手動輸入

.EXAMPLE
    GetFolderTreeStructure -Path "C:\MyProject"
#>

function GetFolderTreeStructure {
    param(
        [string]$Path = ".",
        [string]$Indent = ""
    )

    $Output = @()

    if (-not (Test-Path $Path)) { return }

    # 取得當前目錄下的所有項目（資料夾排前面，檔案排後面）
    $Items = Get-ChildItem -Path $Path | Sort-Object @{Expression="PSIsContainer"; Descending=$true}, Name

    $Count = $Items.Count
    for ($i = 0; $i -lt $Count; $i++) {
        $Item = $Items[$i]
        $IsLast = ($i -eq $Count - 1)
        
        # 根據是否為該層級最後一個項目，決定分支符號
        $Connection = if ($IsLast) { "└── " } else { "├── " }
        $Output += ($Indent + $Connection + $Item.Name)

        # 如果是資料夾，則遞迴進去
        if ($Item.PSIsContainer) {
            # 決定子層級的縮排前綴
            $NewIndent = $Indent + $(if ($IsLast) { "    " } else { "│   " })
            $Output += GetFolderTreeStructure -Path $Item.FullName -Indent $NewIndent
        }
    }

    return $Output
}

<#
.SYNOPSIS
    將目錄樹狀結構匯出至文字檔

.DESCRIPTION
    呼叫遞迴工具 GetFolderTreeStructure，並將產生的陣列格式化後存入指定檔案
    特別處理了 UTF-8 編碼，以確保樹狀圖符號（如 ├──）在文字檔中正常顯示

.PARAMETER TargetFolder
    要掃描的目標資料夾路徑

.PARAMETER OutputFilePath
    匯出結果的檔案路徑（例如：C:\output\tree.txt）

.EXAMPLE
    GetFolderFileTree -TargetFolder "D:\Project" -OutputFilePath ".\project_tree.txt"
#>
function GetFolderFileTree {
    param (
        [string]$TargetFolder = ".",
        [string]$OutputFilePath = ""
    )
    
    if (Test-Path $TargetFolder) {
        Write-Host "正在掃描目錄並寫入檔案..." -ForegroundColor Cyan
        
        # 初始化內容（加入根目錄名稱）
        $FinalResult = @($TargetFolder)
        $FinalResult += GetFolderTreeStructure -Path $TargetFolder
        
        # 輸出至檔案 (使用 UTF8 編碼確保符號不亂碼)
        $FinalResult | Out-File -FilePath $OutputFilePath -Encoding utf8
        
        Write-Host "完成！檔案已儲存至: $OutputFilePath" -ForegroundColor Green
    } else {
        Write-Warning "路徑不存在，請檢查設定。"
    }
}

<#
.SYNOPSIS
    遞迴掃描資料夾中的所有檔案，並匯出詳細清單至 CSV 檔案

.DESCRIPTION
    此函式會遍歷指定路徑下的所有子目錄，提取每個檔案的完整路徑 (FullName) 與檔案大小 (Length)，
    並將結果儲存為結構化的 CSV 格式，方便後續在 Excel 或其他資料分析工具中開啟

.PARAMETER TargetFolder
    要掃描的起始資料夾路徑

.PARAMETER OutputFilePath
    匯出的 CSV 檔案儲存路徑

.EXAMPLE
    GetFolderFileList -TargetFolder "C:\Docs" -OutputFilePath ".\FileInventory.csv"
#>
function GetFolderFileList {
    param (
        [string]$TargetFolder = ".",
        [string]$OutputFilePath = ""
    )

    if (Test-Path $TargetFolder) {
        Write-Host "正在掃描目錄並寫入檔案..." -ForegroundColor Cyan
        
        # -Recurse: 包含子目錄
        # -File: 只顯示檔案 (排除資料夾)
        # -Filter: 篩選特定副檔名
        # Get-ChildItem -Path $TargetPath -Recurse -File -Filter "*.txt"
        Get-ChildItem -Path $TargetFolder -Recurse -File | 
        Select-Object FullName, Length | 
        Export-Csv -Path $OutputFilePath -NoTypeInformation -Encoding utf8
        
        Write-Host "完成！檔案已儲存至: $OutputFilePath" -ForegroundColor Green
    } else {
        Write-Warning "路徑不存在，請檢查設定。"
    }
}