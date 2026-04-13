. "$PSScriptRoot\System\PSCommonTool.ps1"

$ErrorActionPreference = 'Stop'

try {
    $ModuleDir = $PSScriptRoot
    $ManifestPath = Join-Path $ModuleDir "SeanTool.Powershell.psd1"
    $Author = "SeanHo"
    $Description = "SeanTool Meta-Module"
    $Version = "0.0.0"

    $AllScripts = GetAllPowershellScripts -FolderPath $ModuleDir

    $AllFunctions = GetAllPowershellFunctions -Scripts $AllScripts

    Push-Location $ModuleDir

    GenPsm1 -ModuleDir $ModuleDir -Scripts $AllScripts -Prefix "SeanTool.Powershell"

    $NestedModulesList = GetNestedModulesList -ModuleDir $ModuleDir -IgnoreList @("SeanTool.Powershell.psm1")

    GenPsd1 -ManifestPath $ManifestPath -Author $Author -Description $Description -Version $Version

    Update-ModuleManifest -Path $ManifestPath `
                                -FunctionsToExport $AllFunctions `
                                -NestedModules $NestedModulesList `
                                -ErrorAction Stop

    Pop-Location
} catch {
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "Error Occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Red
    
    if (Test-Path ".\SeanTool.Powershell.psd1") { Pop-Location }
    exit 1
}