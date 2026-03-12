<#
.SYNOPSIS
    以Temp資料夾取得檔案目錄結構並備份Source資料夾至Backup資料夾。

.DESCRIPTION
    1. 以 $TempPath 內部的檔案目錄結構作為「比對範本」。
    2. 到 $SourcePath 尋找與範本路徑相同的原始檔案。
    3. 若存在，則將該檔案備份至 $TargetPath，並保持原有的資料夾層級。
    4. 回傳成功與失敗清單

.PARAMETER TempPath
    作為比對基準的暫存資料夾（通常是用來決定「要備份哪些檔案」的 Schema）。
.PARAMETER SourcePath
    存放實際原始檔案的資料夾（備份的來源地）。
.PARAMETER TargetPath
    存放備份結果的目標資料夾。
#>
function BackupFileByTemp {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TempPath,
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    $TempFileList = Get-ChildItem -Path $TempPath -Recurse -File

    $SuccessFileList = @()
    $NotFoundFileList = @()

    foreach($TempFile in $TempFileList){
        $TempItemPath = $TempFile.FullName
        $SourceItemPath = Join-Path $SourcePath $TempItemPath.Replace($TempPath, "")
        $TargetItemPath = Join-Path $TargetPath $TempItemPath.Replace($TempPath, "")

        if(Test-Path $SourceItemPath){
            $TargetItemFolder = Split-Path $TargetItemPath
            New-Item -ItemType Directory -Path $TargetItemFolder -Force | Out-Null

            Copy-Item $SourceItemPath $TargetItemPath -Force
            $SuccessFileList += ,@($SourceItemPath, $TargetItemPath)
        }
        else{
            $NotFoundFileList += $SourceItemPath
        }
    }

    return [PSCustomObject]@{
        SuccessFileList  = $SuccessFileList
        NotFoundFileList = $NotFoundFileList
    }
}

<#
.SYNOPSIS
    輸出備份結果
#>
function GenBackupResult{
    param (
        [object[][]]$SuccessFileList,
        [array]$NotFoundFileList,
        [Parameter(Mandatory = $true)]
        [string]$ResultFilePath
    )
    $SuccessFilePath = Join-Path $ResultFilePath "Success.txt"
    $NotFoundFilePath = Join-Path $ResultFilePath "NotFound.txt"

    $maxLen = 0

    foreach($File in $SuccessFileList){ $maxLen = [Math]::Max($maxLen, $File[0].Length) }

    foreach($File in $SuccessFileList){ $File[0] = $File[0].PadRight($maxLen) }

    $SuccessMsg = ""

    foreach($File in $SuccessFileList){ $SuccessMsg += "$($File[0]) => $($File[1]) $([Environment]::NewLine)" }

    foreach($File in $SuccessFileList){ Write-Host $File[0] }

    if($SuccessFileList) { 
        New-Item -ItemType Directory -Path $ResultFilePath -Force | Out-Null
        $SuccessMsg | Out-File -FilePath $SuccessFilePath -Encoding utf8
    }

    if($NotFoundFileList) { 
        New-Item -ItemType Directory -Path $ResultFilePath -Force | Out-Null
        $NotFoundFileList | Out-File -FilePath $NotFoundFilePath -Encoding utf8 
    }
}

$params = @{
    TempPath   = "C:\GSS\Radar\Project\ECOVE-ESC-Output\Output\20260306\WebRoot"
    SourcePath = "C:\GSS\Radar\Project\ECOVE-ESC-Output\Output\Source\WebRoot"
    TargetPath = "C:\GSS\Radar\Project\ECOVE-ESC-Output\Output\Backup\20260306\WebRoot"
}

$BackupFileList = BackupFileByTemp @params

GenBackupResult -SuccessFileList $BackupFileList.SuccessFileList -NotFoundFileList $BackupFileList.NotFoundFileList -ResultFilePath $TargetPath