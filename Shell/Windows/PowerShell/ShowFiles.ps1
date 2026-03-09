function Get-FolderTreeStructure {
    param(
        [string]$Path = ".",
        [string]$Indent = ""
    )

    $Output = @()

    # 取得當前目錄下的所有項目（資料夾排前面，檔案排後面）
    if (-not (Test-Path $Path)) { return }
    $Items = Get-ChildItem -Path $Path | Sort-Object @{Expression="PSIsContainer"; Descending=$true}, Name

    $Count = $Items.Count
    for ($i = 0; $i -lt $Count; $i++) {
        $Item = $Items[$i]
        $IsLast = ($i -eq $Count - 1)
        
        # 決定連接符號
        $Connection = if ($IsLast) { "└── " } else { "├── " }
        
        # 輸出名稱
        $Output += ($Indent + $Connection + $Item.Name)

        # 如果是資料夾，則遞迴進去
        if ($Item.PSIsContainer) {
            $NewIndent = $Indent + $(if ($IsLast) { "    " } else { "│   " })
            $Output += Get-FolderTreeStructure -Path $Item.FullName -Indent $NewIndent
        }
    }

    return $Output
}

function GetFolderFileTree {
    param (
        [string]$TargetFolder = ".",
        [string]$OutputFilePath = ""
    )
    
    if (Test-Path $TargetFolder) {
        Write-Host "正在掃描目錄並寫入檔案..." -ForegroundColor Cyan
        
        # 初始化內容（加入根目錄名稱）
        $FinalResult = @($TargetFolder)
        $FinalResult += Get-FolderTreeStructure -Path $TargetFolder
        
        # 輸出至檔案 (使用 UTF8 編碼確保符號不亂碼)
        $FinalResult | Out-File -FilePath $OutputFilePath -Encoding utf8
        
        Write-Host "完成！檔案已儲存至: $OutputFilePath" -ForegroundColor Green
    } else {
        Write-Warning "路徑不存在，請檢查設定。"
    }
}

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

GetFolderFileTree -TargetFolder "C:\Data" -OutputFilePath "C:\FileTree.txt"
GetFolderFileList -TargetFolder "C:\Data" -OutputFilePath "C:\FileList.csv"
Read-Host "按下 Enter 鍵以結束..."