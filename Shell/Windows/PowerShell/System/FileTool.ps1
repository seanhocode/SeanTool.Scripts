<#
.SYNOPSIS
    依據暫存目錄結構進行檔案備份與結果紀錄

.DESCRIPTION
    1. 以 $TempPath 內部的檔案目錄結構作為比對範本
    2. 從 $SourcePath 尋找對應路徑的原始檔案
    3. 若檔案存在，則備份至 $TargetPath 並維持原有資料夾層級
    4. 自動呼叫 GenCopyResult 將備份結果（成功、遺失、錯誤）輸出至目標目錄

.PARAMETER TempPath
    [String] 作為比對基準的暫存資料夾，決定要備份哪些檔案的範本結構

.PARAMETER SourcePath
    [String] 實際原始檔案的存放位置，即備份來源地

.PARAMETER TargetPath
    [String] 備份檔案的存放目標位置，同時也是執行結果紀錄檔的輸出路徑

.EXAMPLE
    $pathMappingParams = @{
        TempPath   = "D:\Release\20260101\WebRoot"
        SourcePath = "D:\WebRoot"
        TargetPath = "D:\Backup\20260101\WebRoot"
    }
    BackupFileByTemp @pathMappingParams

.NOTES
    此函式內部依賴 GetBackupPathMapping、CopyFile 與 GenCopyResult 三個自定義函式進行作業
#>
function BackupFileByTemp {
    param (
        [Parameter(Mandatory = $true)] [string]$TempPath,
        [Parameter(Mandatory = $true)] [string]$SourcePath,
        [Parameter(Mandatory = $true)] [string]$TargetPath
    )

    $pathMappingParams = @{
        TempPath   = $TempPath
        SourcePath = $SourcePath
        TargetPath = $TargetPath
    }

    $CopyFileList = GetBackupPathMapping @pathMappingParams

    $CopyResult = CopyFile -CopyFileList $CopyFileList

    $copyResultParams = @{
        SuccessFileList = $CopyResult.SuccessFileList
        NotFoundFileList = $CopyResult.NotFoundFileList
        ErrorFileList = $CopyResult.ErrorFileList
        ResultFilePath = $TargetPath
    }

    GenCopyResult @copyResultParams
}

<#
.SYNOPSIS
    依據暫存目錄結構產生來源與目標路徑的對應清單

.DESCRIPTION
    1. 遍歷 $TempPath 內的所有檔案作為比對基準
    2. 透過字串替換邏輯，將 $TempPath 的相對路徑映射至 $SourcePath 與 $TargetPath
    3. 產出一份預計執行的複製路徑清單，供後續備份作業使用

.PARAMETER TempPath
    [String] 作為基準的暫存資料夾路徑，定義「哪些檔案」需要被處理

.PARAMETER SourcePath
    [String] 原始檔案的實際存放目錄

.PARAMETER TargetPath
    [String] 預計備份到的目標目錄

.OUTPUTS
    [Object[][]] 二維陣列格式的複製清單
    格式：@(@("來源檔案路徑", "目標檔案路徑"), ...)

.EXAMPLE
    $params = @{
        TempPath   = "C:\Temp\Update"
        SourcePath = "C:\Deploy\App"
        TargetPath = "D:\Backup\App"
    }
    $Mapping = GetBackupPathMapping @params
#>
function GetBackupPathMapping{
    param (
        [Parameter(Mandatory = $true)] [string]$TempPath,
        [Parameter(Mandatory = $true)] [string]$SourcePath,
        [Parameter(Mandatory = $true)] [string]$TargetPath
    )

    $TempFileList = Get-ChildItem -Path $TempPath -Recurse -File

    $PathMapping = @()

    foreach($TempFile in $TempFileList){
        $TempItemPath = $TempFile.FullName
        $SourceItemPath = Join-Path $SourcePath $TempItemPath.Replace($TempPath, "")
        $TargetItemPath = Join-Path $TargetPath $TempItemPath.Replace($TempPath, "")

        $PathMapping += ,@($SourceItemPath, $TargetItemPath)
    }

    return $PathMapping
}

<#
.SYNOPSIS
    批次複製檔案並追蹤執行結果

.DESCRIPTION
    此函式接收一個二維陣列的檔案清單，執行複製動作後，會分類並回傳成功、找不到檔案及執行錯誤的詳細清單

.PARAMETER CopyFileList
    [二維陣列] 要執行的複製清單
    格式結構：@(@("來源路徑1", "目標路徑1"), @("來源路徑2", "目標路徑2"))

.OUTPUTS
    回傳一個包含以下屬性的物件 (PSCustomObject)：
    - SuccessFileList: [二維陣列] 成功複製的來源與目標路徑
    - NotFoundFileList: [一維陣列] 來源路徑不存在的檔案清單
    - ErrorFileList: [二維陣列] 因權限或其他原因導致失敗的清單

.EXAMPLE
    $CopyFileList = @()
    $CopyFileList += ,@("C:\Data\File1.txt", "C:\Backup\File1.txt")
    $CopyFileList += ,@("C:\Data\Missing.txt", "C:\Backup\Missing.txt")

    $CopyResult = CopyFile -CopyFileList $CopyFileList

    # 輸出成功結果
    $CopyResult.SuccessFileList | ForEach-Object { Write-Host "成功: $($[0]) 到 $($[1])" }
    
    # 輸出遺失檔案
    $CopyResult.NotFoundFileList | ForEach-Object { Write-Warning "找不到檔案: $_" }
#>
function CopyFile {
    param (
        [Parameter(Mandatory = $true)] [object[][]]$CopyFileList
    )

    $SuccessFileList = @()
    $NotFoundFileList = @()
    $ErrorFileList = @()

    foreach($FilePair in $CopyFileList){
        # Windows 檔案系統的標準分隔符號：反斜線 \
        $SourceItemPath = [System.IO.Path]::GetFullPath($FilePair[0])
        $TargetItemPath = [System.IO.Path]::GetFullPath($FilePair[1])

        # -PathType Leaf => 確保來源是一個「檔案」而不是「資料夾」
        if(Test-Path $SourceItemPath -PathType Leaf){
            try {
                $TargetItemFolder = Split-Path $TargetItemPath

                if (-not (Test-Path -Path $TargetItemFolder)) {
                    New-Item -ItemType Directory -Path $TargetItemFolder -Force | Out-Null
                }

                Copy-Item -Path $SourceItemPath -Destination $TargetItemPath -Force -ErrorAction Stop
                $SuccessFileList += ,@($SourceItemPath, $TargetItemPath)
            }
            catch {
                $ErrorFileList += ,@($SourceItemPath, $TargetItemPath)
            }
        }
        else{
            $NotFoundFileList += $SourceItemPath
        }
    }

    return [PSCustomObject]@{
        SuccessFileList  = $SuccessFileList
        NotFoundFileList = $NotFoundFileList
        ErrorFileList = $ErrorFileList
    }
}

<#
.SYNOPSIS
    尋找檔案清單中的最長路徑並進行格式化輸出

.DESCRIPTION
    此函式接收一個包含多組路徑的二維陣列，計算並找出字元長度最長的路徑對，
    並將其轉換為易讀的指定字串格式（[來源] => [目標]）

.PARAMETER FileList
    [二維陣列] 包含來源與目標路徑的清單。
    格式範例：@(@("C:\Source\Path\File.txt", "D:\Backup\Path\File.txt"))

.OUTPUTS
    [String] 格式化後的字串。
    輸出樣式：[來源檔案路徑] => [目標檔案路徑]

.EXAMPLE
    $Files = @(
        ,@("C:\Short.txt", "D:\Short.txt"),
        ,@("C:\Very\Long\Path\To\File\Target.txt", "E:\Backup\Target.txt")
    )
    GetFormattedLines -FileList $Files
    # 輸出: C:\Very\Long\Path\To\File\Target.txt => E:\Backup\Target.txt

.NOTES
    注意：若有多個路徑長度相同，函式預設回傳第一個找到的最長路徑
#>
function GetFormattedLines {
    param([object[][]]$FileList)

    if ($null -eq $FileList -or $FileList.Count -eq 0) { return $null }

    # 確保抓取的是字串長度，並處理單一元素的狀況
    $lengths = $FileList | ForEach-Object { ([string]$_[0]).Length }
    $maxLen = ($lengths | Measure-Object -Maximum).Maximum

    return $FileList | ForEach-Object { 
        "{0} => {1}" -f ([string]$_[0]).PadRight($maxLen), $_[1] 
    }
}

<#
.SYNOPSIS
    將檔案複製的執行結果分類並匯出為文字檔

.DESCRIPTION
    根據傳入的成功、找不到及錯誤清單，分別在指定目錄下產生 Success.txt、NotFound.txt 與 Error.txt
    若指定路徑不存在，函式會自動建立目錄

.PARAMETER SuccessFileList
    [二維陣列] 成功複製的清單
    格式：@(@("來源路徑", "目標路徑"), ...)

.PARAMETER NotFoundFileList
    [陣列] 來源端找不到檔案的清單
    格式：@("來源路徑1", "來源路徑2", ...)

.PARAMETER ErrorFileList
    [二維陣列] 複製過程中發生錯誤（如權限不足）的清單
    格式：@(@("來源路徑", "目標路徑"), ...)

.PARAMETER ResultFilePath
    [字串] 輸出結果檔案的目標目錄路徑。此為強制參數

.EXAMPLE
    GenCopyResult -SuccessFileList $Success -NotFoundFileList $Missing -ResultFilePath "C:\Logs\CopyReport"
#>
function GenCopyResult{
    param (
        [object[][]]$SuccessFileList,
        [string[]]$NotFoundFileList,
        [object[][]]$ErrorFileList,
        [Parameter(Mandatory = $true)] [string]$ResultFilePath
    )
    if (-not (Test-Path $ResultFilePath)) { 
        New-Item -ItemType Directory -Path $ResultFilePath -Force | Out-Null 
    }

    $SuccessLines = GetFormattedLines -FileList $SuccessFileList
    $ErrorLines   = GetFormattedLines -FileList $ErrorFileList

    if ($SuccessLines) { 
        $SuccessLines | Out-File -FilePath (Join-Path $ResultFilePath "Success.txt") -Encoding utf8 
    }
    if ($NotFoundFileList) { 
        $NotFoundFileList | Out-File -FilePath (Join-Path $ResultFilePath "NotFound.txt") -Encoding utf8 
    }
    if ($ErrorLines) { 
        $ErrorLines | Out-File -FilePath (Join-Path $ResultFilePath "Error.txt") -Encoding utf8 
    }
}

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