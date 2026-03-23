. "$PSScriptRoot\CopyFile.ps1"

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
        SourcePath = "C:\Live\App"
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