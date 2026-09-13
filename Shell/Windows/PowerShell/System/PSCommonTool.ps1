function Get-PowerShellScripts {
    <#
    .SYNOPSIS
        自動掃描 PowerShell 原始碼，更新 SeanTool.Powershell.psd1 的 FunctionsToExport 與 NestedModules
        並自動建立缺失的子模組 (.psm1) 檔案
    #>

    <#
    .SYNOPSIS
        取得指定目錄下所有的 .ps1 腳本檔案。

    .DESCRIPTION
        遞迴掃描指定資料夾下的 PowerShell 腳本檔案，並排除更新 manifest 的自我腳本。

    .PARAMETER FolderPath
        要掃描的根目錄路徑。

    .OUTPUTS
        [System.IO.FileInfo[]] 包含所有 .ps1 檔案的陣列。

    .EXAMPLE
        Get-PowerShellScripts -FolderPath "C:\Scripts"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
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

function Get-PowerShellFunctions {
    <#
    .SYNOPSIS
        掃描腳本內容並擷取所有可匯出的函式名稱。

    .DESCRIPTION
        透過正規表示式解析腳本檔案內容，找出所有公開函式名稱，並排除以下底線開頭的私有函式。

    .PARAMETER Scripts
        由 Get-PowerShellScripts 取得的腳本檔案陣列。

    .OUTPUTS
        [string[]] 準備要匯出的函式名稱清單。

    .EXAMPLE
        Get-PowerShellFunctions -Scripts (Get-PowerShellScripts -FolderPath "C:\Scripts")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Scripts
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

function Get-NestedModulesList {
    <#
    .SYNOPSIS
        取得所有子模組的相對路徑清單，供 psd1 使用。

    .DESCRIPTION
        搜尋指定模組目錄下所有 .psm1 檔案，並轉換為相對路徑清單。

    .PARAMETER ModuleDir
        模組的根目錄路徑。

    .PARAMETER IgnoreList
        要忽略的子模組檔名清單。

    .OUTPUTS
        [string[]] 巢狀模組的相對路徑清單。

    .EXAMPLE
        Get-NestedModulesList -ModuleDir "C:\Repo\MyModule"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleDir,
        [Parameter(Mandatory = $false)]
        [string[]]$IgnoreList
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

function New-SubmoduleFile {
    <#
    .SYNOPSIS
        檢查子目錄是否有對應的 .psm1 檔案，若缺少則自動建立。

    .DESCRIPTION
        針對包含 .ps1 檔案的子目錄，若缺乏對應的子模組檔案，則自動建立 .psm1 檔案。

    .PARAMETER ModuleDir
        模組的根目錄絕對路徑，用於避免在根目錄下建立子模組。

    .PARAMETER Scripts
        所有被掃描到的腳本檔案陣列。

    .PARAMETER Prefix
        可選的 .psm1 檔案名稱前綴，後面會接上資料夾名稱。

    .EXAMPLE
        New-SubmoduleFile -ModuleDir "C:\Repo\MyModule" -Scripts (Get-PowerShellScripts -FolderPath "C:\Repo\MyModule")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleDir,
        [Parameter(Mandatory = $true)]
        [array]$Scripts,
        [Parameter(Mandatory = $false)]
        [string]$Prefix
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
# Automatically generated submodule file ($Psm1Name)
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

function New-ModuleManifestFile {
    <#
    .SYNOPSIS
        確認主模組清單檔 (.psd1) 是否存在，若不存在則建立基底檔案。

    .DESCRIPTION
        若指定的 manifest 檔案不存在，會建立新的 PowerShell module manifest。

    .PARAMETER ManifestPath
        要建立或更新的 .psd1 檔案路徑。

    .PARAMETER Author
        模組作者名稱。

    .PARAMETER Description
        模組描述。

    .PARAMETER Version
        模組版本號。

    .EXAMPLE
        New-ModuleManifestFile -ManifestPath "C:\Repo\MyModule\MyModule.psd1" -Author "Sean" -Description "My module" -Version "1.0.0"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,
        [Parameter(Mandatory = $true)]
        [string]$Author,
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    # 檢查並建立基底 Manifest
    if (-not (Test-Path $ManifestPath)) {
        Write-Host "Not found .psd1, Creating new manifest..." 
        New-ModuleManifest -Path $ManifestPath -Author $Author -Description $Description -ModuleVersion $Version
    } else {
        Write-Host "Found existing .psd1, Updating export list only..."
    }
}

function Import-DllLibraries {
    <#
    .SYNOPSIS
        批次載入指定的 .NET DLL 檔案。

    .DESCRIPTION
        掃描指定目錄下的 DLL 檔案，並使用 Add-Type 將其載入目前的 PowerShell 工作階段中。

    .PARAMETER LibraryPath
        存放 DLL 檔案的資料夾路徑。

    .PARAMETER DllNames
        要載入的 DLL 檔案名稱清單。若未指定，則會載入 LibraryPath 下的所有 DLL 檔案。

    .EXAMPLE
        Import-DllLibraries -LibraryPath "C:\libs" -DllNames @("A.dll", "B.dll")
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LibraryPath,
        [Parameter(Mandatory = $false)]
        [array]$DllNames = @()
    )

    <#
        [process 區塊的作用]
        當使用管線 (Pipeline) 傳入多個路徑時，
        PowerShell 會自動針對每個物件執行一次此區塊
        即使只傳入單一參數，此處的邏輯也會被執行一次
    #>
    process {
        # 確保在 process 內部建立一個區域複本，避免修改到參數原始定義
        $targetDlls = $DllNames

        # 如果沒指定檔名，自動抓取該路徑下所有 dll
        if ($targetDlls.Count -eq 0) {
            if (Test-Path $LibraryPath) {
                $targetDlls = Get-ChildItem -Path $LibraryPath -Filter "*.dll" | Select-Object -ExpandProperty Name
            } else {
                Write-Error "Path not found: $LibraryPath"
                return
            }
        }
        
        foreach ($dllName in $targetDlls) {
            $fullPath = Join-Path $LibraryPath $dllName
            
            if (Test-Path $fullPath) {
                try {
                    # 避免重複載入同一型別導致的 Error (雖然 Add-Type 會自動處理，但 Verbose 更有助於偵錯)
                    Add-Type -Path $fullPath -ErrorAction Stop
                    Write-Verbose "Load success: $dllName"
                } 
                catch {
                    $errMsg = $_.Exception.Message
                    Write-Warning "Load $dllName fail: $errMsg"
                    
                    # 檢查是否為 ReflectionTypeLoadException
                    if ($_.Exception.InnerException -is [System.Reflection.ReflectionTypeLoadException] -or 
                        $_.Exception -is [System.Reflection.ReflectionTypeLoadException]) {
                        
                        $loaderEx = $_.Exception.LoaderExceptions
                        if ($null -eq $loaderEx) { $loaderEx = $_.Exception.InnerException.LoaderExceptions }

                        foreach ($ex in $loaderEx) {
                            Write-Error "Detail: $($ex.Message)"
                        }
                    }
                }
            } else {
                Write-Error "Not found: $fullPath"
            }
        }
    }
}