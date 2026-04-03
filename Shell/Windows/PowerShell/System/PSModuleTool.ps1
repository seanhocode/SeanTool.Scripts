<#
.SYNOPSIS
    自動掃描 PowerShell 原始碼，更新 SeanTool.Powershell.psd1 的 FunctionsToExport 與 NestedModules
    並自動建立缺失的子模組 (.psm1) 檔案
#>

<#
.SYNOPSIS
    取得指定目錄下所有的 .ps1 腳本檔案
.PARAMETER FolderPath
    要掃描的根目錄路徑
.OUTPUTS
    [System.IO.FileInfo[]] 包含所有 .ps1 檔案的陣列
#>
function GetAllPowershellScripts{
    param(
        [Parameter(Mandatory = $true)] [string]$FolderPath
    )
    Write-Host "=================================================="
    Write-Host "Start scanning scripts...`n"
    $AllScripts = Get-ChildItem -Path $FolderPath -Recurse -Filter "*.ps1" | Where-Object { $_.Name -ne "UpdateManifest.ps1" }# 排除 UpdateManifest.ps1 自身

    Write-Host "Find:"
    foreach($Script In $AllScripts) {
        Write-Host $($Script)
    }
    Write-Host "=================================================="
    return $AllScripts
}

<#
.SYNOPSIS
    掃描傳入的腳本檔案內容，透過正規表示式萃取所有公開的 Function 名稱
.PARAMETER Scripts
    從 GetAllPowershellScripts 取得的腳本檔案陣列
.OUTPUTS
    [string[]] 準備要匯出的 Function 名稱清單（已過濾掉私有函式）
#>
function GetAllPowershellFunctions{
    param(
        [Parameter(Mandatory = $true)] [array]$Scripts
    )

    $ExportList = @()

    Write-Host "=================================================="
    Write-Host "Start scanning functions...`n"
    # 使用正規表示式掃描檔案內容，找出所有 Function 名稱
    foreach ($File in $Scripts) {
        $Content = Get-Content $File.FullName -Raw
        
        # 匹配 "function 函式名稱 {" 的語法
        $Matches = [regex]::Matches($Content, '(?im)^\s*function\s+([a-zA-Z0-9_-]+)')
        
        foreach ($Match in $Matches) {
            $FuncName = $Match.Groups[1].Value
            
            # [黑名單機制]：自動忽略以底線開頭的函式
            if ($FuncName -notmatch '^_') {
                $ExportList += $FuncName
            }
        }
    }

    # 確保名單不重複並排序
    $ExportList = $ExportList | Select-Object -Unique | Sort-Object

    Write-Host "Find:"

    foreach($Function In $ExportList) {
        Write-Host $Function
    }
    Write-Host "=================================================="

    return $ExportList
}

<#
.SYNOPSIS
    尋找所有子模組 (.psm1) 並轉換為供 psd1 使用的相對路徑清單
.PARAMETER ModuleDir
    模組的根目錄路徑
.OUTPUTS
    [string[]] 巢狀模組的相對路徑清單
#>
function GetNestedModulesList{
    param(
        [Parameter(Mandatory = $true)] [string]$ModuleDir,
        [Parameter(Mandatory = $false)] [string[]]$IgnoreList
    )

    # 掃描所有的子模組 (.psm1) 來自動更新 NestedModules
    Write-Host "=================================================="
    Write-Host "Start scanning NestedModules...`n"
    # 尋找所有 .psm1 檔案
    $Psm1Files = Get-ChildItem -Path $ModuleDir -Recurse -Filter "*.psm1"
    $NestedModulesList = @()

    foreach ($Psm1 in $Psm1Files) {
        # 防呆：排除可能存在的根模組 (避免自我無限載入)
        if ($null -ne $IgnoreList -and $IgnoreList -contains $Psm1.Name) { continue }
        
        # 計算相對路徑 (將絕對路徑中的根目錄字串替換掉，前面補上 .)
        # 例如： C:\Repo\PowerShell\Git\Git.psm1 => .\Git\Git.psm1
        $RelativePath = "." + $Psm1.FullName.Replace($ModuleDir, "")
        $NestedModulesList += $RelativePath
    }

    Write-Host "Find:"
    $NestedModulesList | ForEach-Object { Write-Host $_}
    Write-Host "=================================================="
    return $NestedModulesList
}

<#
.SYNOPSIS
    檢查包含 .ps1 腳本的子目錄，若缺乏對應的 .psm1 則自動建立該子模組檔案
    
.PARAMETER ModuleDir
    模組的根目錄絕對路徑。用於比對以確保不會在根目錄下建立子模組

.PARAMETER Scripts
    所有被掃描到的腳本檔案陣列（通常為 Get-ChildItem 取得的 FileInfo 陣列）

.PARAMETER Prefix
    選用參數。自訂生成的 .psm1 檔案名稱前綴，後面會接上資料夾名稱
    若未提供或為空字串，預設使用資料夾名稱作為 .psm1 名稱
#>
function GenPsm1{
    param(
        [Parameter(Mandatory = $true)] [string]$ModuleDir,
        [Parameter(Mandatory = $true)] [array]$Scripts,
        [Parameter(Mandatory = $false)] [string]$Prefix
    )

    $ScriptGroups = $Scripts | Group-Object DirectoryName

    foreach ($Group in $ScriptGroups) {
        $DirPath = $Group.Name
        
        # 我們只針對「子資料夾」建立 .psm1，忽略放在根目錄的 .ps1
        if ($DirPath -ne $ModuleDir) {
            $FolderName = Split-Path $DirPath -Leaf
            $Psm1Name = "${FolderName}.psm1"
            if($Prefix -ne $null -and $Prefix -ne "") {
                $Psm1Name = "${Prefix}.${FolderName}.psm1"
            }
            $Psm1Path = Join-Path $DirPath $Psm1Name

            # 如果該資料夾底下沒有專屬的 .psm1，就自動生成一個！
            if (-not (Test-Path $Psm1Path)) {
                Write-Host "Find folder '$FolderName' but not found $Psm1Name, Creating..."
                
                # 定義標準的子模組載入邏輯
                $Psm1Content = @"
# ======================================================================
# 自動產生的子模組檔案 ($Psm1Name)
# ======================================================================
`$ScriptFiles = Get-ChildItem -Path `$PSScriptRoot -Filter "*.ps1"

foreach (`$File in `$ScriptFiles) {
    . `$File.FullName
}

Export-ModuleMember -Function *
"@
                # 寫入檔案 (使用 UTF8 避免中文註解亂碼)
                Set-Content -Path $Psm1Path -Value $Psm1Content -Encoding UTF8
            }
        }
    }
}

<#
.SYNOPSIS
    檢查主模組清單檔 (.psd1) 是否存在，若不存在則初始化一個基底檔案
#>
function GenPsd1{
    param(
        [Parameter(Mandatory = $true)] [string]$ManifestPath,
        [Parameter(Mandatory = $true)] [string]$Author,
        [Parameter(Mandatory = $true)] [string]$Description,
        [Parameter(Mandatory = $true)] [string]$Version
    )

    # 檢查並建立基底 Manifest
    if (-not (Test-Path $ManifestPath)) {
        Write-Host "Not found .psd1, Creating new manifest..." 
        New-ModuleManifest -Path $ManifestPath -Author $Author -Description $Description -ModuleVersion $Version
    } else {
        Write-Host "Found existing .psd1, Updating export list only..."
    }
}