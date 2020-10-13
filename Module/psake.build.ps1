properties {
    $ModuleName = ""
    $OutputPath = Join-Path -Path .\ -ChildPath Output
    $ModulePath = Join-Path -Path $OutputPath -ChildPath $ModuleName
}

task default -depends clean, build, test

task Test {
    Import-Module $ModulePath
    $IsLoaded = Get-Module $ModuleName

    if (!($IsLoaded -eq $Null)) {
        Write-Host -ForegroundColor Green "$ModuleName Loaded Successfully."
    }
    Remove-Module $ModuleName
}

task Clean {
    if (Test-Path -Path "$OutputPath") {
        Remove-Item -Path $OutputPath -Recurse
        New-Item -Path .\ -ItemType Directory -Name "Output" | Out-Null
        New-Item -Path $OutputPath -Name $ModuleName -ItemType Directory | Out-Null
    } else {
        New-Item -Path .\ -ItemType Directory -Name "Output" | Out-Null
        New-Item -Path $OutputPath -Name $ModuleName -ItemType Directory | Out-Null
    }

}

task Build -depends Clean {
    $PrivateFunctions = Get-ChildItem ".\SRC\Functions\Private"
    $PublicFunctions = Get-ChildItem ".\SRC\Functions\Public"
    $Classes = Get-ChildItem ".\SRC\Classes\"
    $FunctionsToExport = $PublicFunctions.BaseName

    Update-ModuleManifest -Path ".\SRC\$ModuleName.psd1" -FunctionsToExport $FunctionsToExport

    Copy-Item -Path ".\SRC\$ModuleName.psd1" -Destination $ModulePath
    Copy-Item -Path ".\SRC\$ModuleName.psm1" -Destination $ModulePath
    
    # Export Classes
    foreach ($Class in $Classes) {
        $Content = Get-Content -Path $Class.FullName
        Add-Content -Value $content -Path "$ModulePath\$ModuleName.psm1"
    }
    
    # Export Private Functions
    foreach ($PrivateFunction in $PrivateFunctions) {
        $Content = Get-Content -Path $PrivateFunction.FullName
        Add-Content -Value $content -Path "$ModulePath\$ModuleName.psm1"
    }

    # Export Public Functions
    foreach ($PublicFuntion in $PublicFunctions) {
        $Content = Get-Content -Path $PublicFuntion.FullName
        Add-Content -Value $content -Path "$ModulePath\$ModuleName.psm1"
    }

}

task Publish -depends Build, Test {
    Publish-Module -Name $ModulePath -Repository "MPSPSRepo"
}

