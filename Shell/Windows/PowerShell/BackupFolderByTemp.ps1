. "$PSScriptRoot\CopyFile.ps1"

<#
Example:
    $pathMappingParams = @{
        TempPath   = "D:\Release\20260101\WebRoot"
        SourcePath = "D:\WebRoot"
        TargetPath = "D:\Backup\20260101\WebRoot"
    }

    BackupFileByTemp @pathMappingParams

Description:
    以Temp資料夾取得檔案目錄結構並備份Source資料夾至Backup資料夾

    1. 以 $TempPath 內部的檔案目錄結構作為「比對範本」
    2. 到 $SourcePath 尋找與範本路徑相同的原始檔案
    3. 若存在，則將該檔案備份至 $TargetPath，並保持原有的資料夾層級
    4. 輸出結果到$TargetPath

ParameterDesc:
    $TempPath
        作為比對基準的暫存資料夾（用來決定「要備份哪些檔案」的 Schema）
    $SourcePath
        存放實際原始檔案的資料夾（備份的來源地）
    $TargetPath
        存放備份結果的目標資料夾
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
Description:
    以Temp資料夾取得檔案目錄結構並輸出複製檔案清單

ParameterDesc:
    $TempPath
        作為比對基準的暫存資料夾（用來決定「要備份哪些檔案」的 Schema）
    $SourcePath
        存放實際原始檔案的資料夾（備份的來源地）
    $TargetPath
        存放備份結果的目標資料夾

ReturnDesc:
    格式:[二維陣列]第一個為來源檔案路徑，第二個為目標檔案路徑
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