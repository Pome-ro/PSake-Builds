[cmdletbinding()]
param(
    [string[]]$Tasks = 'default'
)
if (!(Get-Module -Name Pester -ListAvailable)) { Install-Module -Name Pester -Scope CurrentUser }
if (!(Get-Module -Name psake -ListAvailable)) { Install-Module -Name psake -Scope CurrentUser }
if (!(Get-Module -Name PSDeploy -ListAvailable)) { Install-Module -Name PSDeploy -Scope CurrentUser }

Invoke-PSake -buildFile .\psake.build.ps1 -taskList $tasks -nologo
