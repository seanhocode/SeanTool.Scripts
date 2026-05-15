$Script:MSBuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"

<#
    .SYNOPSIS
        建置專案(debug)
    .DESCRIPTION
        使用 MSBuild 建置指定的解決方案，並設定為 Debug 模式和 Any CPU 平台
    .PARAMETER SolutionFolderPath
        指定解決方案所在的資料夾路徑
    .PARAMETER SolutionName
        指定解決方案的名稱（含副檔名）
    .PARAMETER MSBuildPath
        指定 MSBuild 的路徑
    .EXAMPLE
        $repoPath = "C:\Project\MyProject"
        $solutionFolderPath = Join-Path $repoPath "Src"
        $solutionName = "MyProject.sln"

        BuildDebugProject -SolutionFolderPath $solutionFolderPath -SolutionName $solutionName -MSBuildPath $msBuildPath
#>
function BuildDebugProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string]$SolutionFolderPath,
        [Parameter(Mandatory=$true)] [string]$SolutionName,
        [Parameter(Mandatory=$false)] [string]$MSBuildPath = $Script:MSBuild
    )

    process {
        Push-Location $SolutionFolderPath

        $solutionPath = Join-Path $SolutionFolderPath $SolutionName

        # 建置專案(debug)
        & $msBuildPath "$solutionPath" /p:Configuration=Debug /p:Platform="Any CPU"

        Pop-Location
    }
}

<#
    .SYNOPSIS
        發佈專案
    .DESCRIPTION
        使用 MSBuild 發佈指定的解決方案，並使用指定的發佈設定檔
    .PARAMETER SolutionFolderPath
        指定解決方案所在的資料夾路徑
    .PARAMETER SolutionName
        指定解決方案的名稱（含副檔名）
    .PARAMETER PublishProfile
        指定發佈設定檔名稱（不需要副檔名）
    .PARAMETER MSBuildPath
        指定 MSBuild 的路徑，預設為 $Script:MSBuild
    .EXAMPLE
        $repoPath = "C:\Project\MyProject"
        $solutionFolderPath = Join-Path $repoPath "Src"
        $solutionName = "MyProject.sln"
        $publishProfile = "Release"

        PublishProject -SolutionFolderPath $solutionFolderPath -SolutionName $solutionName -PublishProfile $publishProfile
#>
function PublishProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string]$SolutionFolderPath,
        [Parameter(Mandatory=$true)] [string]$SolutionName,
        [Parameter(Mandatory=$true)] [string]$PublishProfile,
        [Parameter(Mandatory=$false)] [string]$MSBuildPath = $Script:MSBuild
    )

    process {
        Push-Location $SolutionFolderPath

        $solutionPath = Join-Path $SolutionFolderPath $SolutionName

        # 發佈專案
        # DeployOnBuild=true: 告訴 MSBuild 在編譯完後接著執行部署動作
        # PublishProfile: 指定你的 .pubxml 檔案名稱（不需要副檔名）(位於:Properties\PublishProfiles)
        & $msBuildPath "$solutionPath" /p:Configuration=Release /p:DeployOnBuild=true /p:PublishProfile="$PublishProfile"

        Pop-Location
    }
}