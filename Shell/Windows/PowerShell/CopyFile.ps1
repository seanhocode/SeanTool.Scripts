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