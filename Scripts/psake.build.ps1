properties {
    $ScriptName = ""
    $OutputPath = Join-Path -Path .\ -ChildPath Output
    $ScriptPath = Join-Path -Path $OutputPath -ChildPath $ScriptName
}

task default -depends clean, build, test

task Test {
    Write-Host "Not Sure what this should be yet"
}

task Clean {
    if (Test-Path -Path "$OutputPath") {
        Remove-Item -Path $OutputPath -Recurse
        New-Item -Path .\ -ItemType Directory -Name "Output" | Out-Null
        New-Item -Path $OutputPath -Name $ScriptName -ItemType Directory | Out-Null
    } else {
        New-Item -Path .\ -ItemType Directory -Name "Output" | Out-Null
        New-Item -Path $OutputPath -Name $ScriptName -ItemType Directory | Out-Null
    }

}

task Build -depends Clean {
    $Functions = Get-ChildItem ".\SRC\Functions\"

    Copy-Item -Path ".\SRC\$ScriptName.ps1" -Destination $ScriptPath
    Copy-Item -Path ".\SRC\Config.psd1" -Destination $ScriptPath
    
    # Export Public Functions
    foreach ($Function in $Functions) {
        $Content = Get-Content -Path $Function.FullName | Out-String
        $Content + (Get-Content -Path "$ScriptPath\$ScriptName.ps1" | Out-String) | Set-Content "$ScriptPath\$ScriptName.ps1"
        # Add-Content -Value $content -Path "$ScriptPath\$ScriptName.psm1"
    }
    $Content = Get-Content -Path .\src\ScriptProperties.ps1 | Out-String
    $Content + (Get-Content -Path "$ScriptPath\$ScriptName.ps1" | Out-String) | Set-Content "$ScriptPath\$ScriptName.ps1"

}

task Publish -depends Build, Test {
    Publish-Script -Path "$ScriptPath\$ScriptName.ps1" -Repository "MPSPSRepo"
}

task Exe -depends Build, Test {
    
}
