<#
Example:

$CopyFileList = @()

$CopyFileList += ,@("C:\Data\File1.txt", "C:\Backup\Data\File1.txt")
$CopyFileList += ,@("C:\Data\File2.txt", "C:\Backup\Data\File2.txt")
$CopyFileList += ,@("C:\Data\NotExists1.txt", "C:\Backup\Data\NotExists1.txt")
$CopyFileList += ,@("C:/Data/File3.txt", "C:/Backup/Data/File3.txt")
$CopyFileList += ,@("C:/Data/File4.txt", "C:/Backup/Data/File4.txt")
$CopyFileList += ,@("C:/Data/NotExists2.txt", "C:/Backup/Data/NotExists2.txt")

$CopyResult = CopyFile -CopyFileList $CopyFileList

foreach($File in $CopyResult.SuccessFileList){ Write-Host "Success:$($File[0]) => $($File[1])" }
foreach($File in $CopyResult.NotFoundFileList){ Write-Host "NotFound:$($File)" }

Description:
    複製檔案，並回傳執行結果

ParameterDesc:
    $CopyFileList
        要複製檔案清單
        格式:[二維陣列]第一個放來源檔案路徑，第二個放目標檔案路徑

ReturnDesc:
    $SuccessFileList
        成功複製清單
        格式:[二維陣列]第一個為來源檔案路徑，第二個為目標檔案路徑

    $NotFoundFileList
        找不到檔案清單
        格式:[陣列]來源檔案路徑(找不到)

    $ErrorFileList
        錯誤清單
        格式:[二維陣列]第一個為來源檔案路徑，第二個為目標檔案路徑
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
Description:
    找到最長路徑並格式化

ParameterDesc:
    $FileList
        檔案清單
        格式:[二維陣列]第一個為來源檔案路徑，第二個為目標檔案路徑

ReturnDesc:
    格式:[來源檔案路徑] => [目標檔案路徑]
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
Description:
    輸出複製結果成txt檔至指定位置

ParameterDesc:
    $SuccessFileList
        成功複製清單
        格式:[二維陣列]第一個放來源檔案路徑，第二個放目標檔案路徑

    $NotFoundFileList
        找不到檔案清單
        格式:[陣列]來源檔案路徑

    $ErrorFileList
        錯誤清單
        格式:[二維陣列]第一個放來源檔案路徑，第二個放目標檔案路徑

    $ResultFilePath
        結果檔案路徑
        格式:[字串]輸出檔案路徑
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