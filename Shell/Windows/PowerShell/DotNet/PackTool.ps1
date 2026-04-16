<#
.SYNOPSIS
    批次將指定的專案編譯並封裝為 NuGet 套件 (.nupkg)

.DESCRIPTION
    針對每一個傳入的專案路徑，會依序執行 Clean (清理)、Build (編譯) 以及 Pack (打包) 動作
    最後會將打包完成的 .nupkg 檔案統一輸出至指定的目標資料夾

.PARAMETER ProjectFullPaths
    包含要打包的專案絕對路徑陣列。可以是包含 .csproj 的資料夾路徑，或是 .csproj 檔案本身的路徑

.PARAMETER TargetFolder
    打包後的 NuGet 套件 (.nupkg) 要輸出的目標資料夾絕對路徑

.EXAMPLE
    $RootPath = Split-Path -Path $PSScriptRoot -Parent
    $TargetDir = Join-Path $RootPath "nupkgs"
    
    # 定義要打包的專案完整路徑
    $ProjectsToPack = @(
        (Join-Path $RootPath "Src\FileTool"),
        (Join-Path $RootPath "Src\JsonTool"),
        (Join-Path $RootPath "Src\ApiTool")
    )

    PackProject -ProjectFullPaths $ProjectsToPack -TargetFolder $TargetDir

.NOTES
    如果專案未設定 package 相關資訊，則會使用預設值來生成 .nupkg 包
#>
function PackProject{
    param (
        [Parameter(Mandatory = $true)] [array]$ProjectFullPaths,
        [Parameter(Mandatory = $true)] [string]$TargetFolder
    )

    # 確保輸出目錄存在，若不存在則自動建立
    if (-not (Test-Path $TargetFolder)) {
        Write-Host "Target folder does not exist. Creating: $TargetFolder" -ForegroundColor DarkGray
        New-Item -ItemType Directory -Path $TargetFolder | Out-Null
    }

    foreach($ProjectFullPath in $ProjectFullPaths) {
        if(Test-Path $ProjectFullPath){
            Write-Host "========================================"
            Write-Host "Processing Project: $ProjectFullPath" -ForegroundColor Cyan

            dotnet clean $ProjectFullPath -c Release
            dotnet restore $ProjectFullPath
            dotnet build $ProjectFullPath -c Release --no-restore
            dotnet pack $ProjectFullPath -c Release -o $TargetFolder --no-build

            Write-Host "========================================"
        }
        else{
            Write-Host "Project path for $ProjectFullPath does not exist."
        }
    }

    Write-Host "All pack completed." -ForegroundColor Green
}

<#
.SYNOPSIS
    將指定的 NuGet 套件 (.nupkg) 推送到目標 NuGet 伺服器或來源

.DESCRIPTION
    此函式封裝了 `dotnet nuget push` 指令

.PARAMETER PackagePath
    必填。要推送的 NuGet 套件 (.nupkg) 的完整或相對路徑。支援萬用字元 (例如: "*.nupkg")

.PARAMETER Source
    必填。目標 NuGet 伺服器的 URL 或預先設定好的來源名稱 (例如: "github" 或 "https://api.nuget.org/v3/index.json")

.PARAMETER ApiKey
    必填。用於驗證身分的 API 金鑰 (API Key) 或 GitHub Token (PAT)

.PARAMETER SkipDuplicate
    選填。加上此開關，當伺服器上已經存在相同版本的套件時，會略過推送而不會拋出錯誤

.PARAMETER Timeout
    選填。推送操作的超時時間（以秒為單位）。如果大於 0，將會覆寫預設的超時設定

.PARAMETER NoServiceEndpoint
    選填。如果加上此開關，將不會將 "api/v2/package" 附加到來源 URL
    (針對某些自訂或私有 NuGet 伺服器 (如 GitHub Packages) 解決 404 錯誤時很有用)

.EXAMPLE
    PushNuGetPackage -PackagePath ".\bin\Release\MyPackage.1.0.0.nupkg" -Source "https://nuget.pkg.github.com/seanhocode/index.json" -ApiKey "ghp_xxxxxxxxxxxx" -SkipDuplicate

.EXAMPLE
    PushNuGetPackage -PackagePath "*.nupkg" -Source "nuget.org" -ApiKey "oy2a..." -Timeout 600 -NoServiceEndpoint

.EXAMPLE
    $ProjectPath = Split-Path -Path $PSScriptRoot -Parent
    $PackageFolderName = "nupkgs"
    $TargetFolder = Join-Path $ProjectPath $PackageFolderName

    $githubToken = "ghp_xxxxxxxxxxxx" 
    $githubOwner = "seanhocode"
    $sourceUrl   = "https://nuget.pkg.github.com/$githubOwner/index.json"

    $packages = Get-ChildItem -Path $TargetFolder -Filter "*.nupkg"

    if ($packages.Count -eq 0) {
        Write-Warning "Not found in '$nupkgFolder'"
        exit
    }

    foreach ($pkg in $packages) {
        PushNuGetPackage `
            -PackagePath $pkg.FullName `
            -Source $sourceUrl `
            -ApiKey $githubToken `
            -SkipDuplicate
    }

.NOTES
    當使用 Personal Access Token (PAT) 推送套件時，套件預設會發佈到「帳號全域」底下，而不會顯示在特定的 Repository 頁面中
    (這與在 GitHub Actions 中使用綁定 Repo 的 GITHUB_TOKEN 行為不同)

    解決方案：
    在專案的 .csproj 檔案中加入 RepositoryUrl 屬性，這樣 GitHub 解析套件時就能自動將其與指定的 Repo 建立連結：

    <PropertyGroup>
        <RepositoryUrl>https://github.com/帳號/Repo名稱</RepositoryUrl>
        <RepositoryType>git</RepositoryType>
    </PropertyGroup>
#>
function PushNuGetPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$PackagePath,

        [Parameter(Mandatory=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$ApiKey,

        [Parameter(Mandatory=$false)]
        [switch]$SkipDuplicate,

        [Parameter(Mandatory=$false)]
        [int]$Timeout,

        [Parameter(Mandatory=$false)]
        [switch]$NoServiceEndpoint
    )

    process {
        Write-Host "========================================"
        Write-Host "Pushing: $(Split-Path $PackagePath -Leaf)"

        # 構建參數陣列，這在 PowerShell 中稱為 Splatting 的變體，但這裡直接組合字串
        $args = @("nuget", "push", "$PackagePath")
        $args += "--source", "$Source"
        $args += "--api-key", "$ApiKey"
        $args += "--timeout", "$Timeout"

        if ($SkipDuplicate) { $args += "--skip-duplicate" }
        
        if ($NoServiceEndpoint) { $args += "--no-service-endpoint" }

        if ($Timeout-gt 0) { $args += "--timeout", "$Timeout" }

        dotnet $args
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Push succeeded." -ForegroundColor Green
        } else {
            Write-Error "Push failed. Exit code: $LASTEXITCODE"
        }
        Write-Host "========================================"
    }
}