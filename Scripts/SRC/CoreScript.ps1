# ---------------- Start Script ---------------- #
$Config = Import-PowershellDataFile -Path "$PSScriptRoot\Config.psd1"
$Data = Import-PowershellDataFile -Path (Join-Path -Path $Config.BaseDirectory -ChildPath $Config.DataBlobFileName)
Import-Module -Name $Config.RequiredModules

$OutplacedID = $Data.School.ID.Outplaced
$PSStudents = Get-MPSAStudent -filter {$_.SchoolID -ne $OutplacedID} -DataBlob $Data
$StudentDBPath = (Join-Path -Path $Data.rootPath -ChildPath $Data.fileNames.studentAccountDB)
$StudentDB = Import-CSV -Path $StudentDBPath

# Filter out Outplaced students

$ADUsers = Get-ADUser -Filter "*" -Properties distinguishedname,SamAccountName,UserPrincipalName,Employeenumber
$Dif = Compare-Object -ReferenceObject ($StudentDB.GUID) -DifferenceObject ($ADUsers.Employeenumber | Where {$_ -ne $Null})

$NewStudents = $Dif | Where-Object {$_.SideIndicator -eq "<="}
$OffboardingStudents = $Dif | Where-Object {$_.SideIndicator -eq "=>"}

$CompletedEleAccounts = @()
$CompletedMSAccounts = @()
ForEach ($ID in $NewStudents){
    $NewStudent = $PSStudents | Where-Object {$_.GUID -eq $ID.InputObject}
    $StudentDBData = $StudentDB | Where-Object {$_.GUID -eq $ID.InputObject}
    
    $NewStudent | Add-Member -MemberType NoteProperty -Name SamAccountName -Value $StudentDBData.SamAccountName
    $NewStudent | Add-Member -MemberType NoteProperty -Name OU -Value $StudentDBData.OU
    $NewStudent | Add-Member -MemberType NoteProperty -Name EMail -Value $StudentDBData.Email
    $NewStudent | Add-Member -MemberType NoteProperty -Name GradYear -Value $StudentDBData.GradYear
    $NewStudent | Add-Member -MemberType NoteProperty -Name Password -Value (ConvertTo-SecureString -String $StudentDBData.PasswordAsPlainText -AsPlainText -force) 
    $NewStudent | Add-Member -MemberType NoteProperty -Name PasswordAsPlainText -Value $StudentDBData.PasswordAsPlainText
    $NewStudent | Add-Member -MemberType NoteProperty -Name ADGroups -Value $($StudentDBData.ADGroups -split ",")
    
    $NewStudent =  Generate-StudentADProperties -student $NewStudent -datablob $data
    #$NewStudent =  Generate-StudentADGroups -student $NewStudent -datablob $data
    $NewStudent =  Generate-StudentHomeDirPath -student $NewStudent -datablob $Data
    
    Write-Host "$($ID.InputObject) Creating Account.." 
    Write-Host $NewStudent.SamAccountName
   

    if ($NewStudent.homedirectory -ne "") {
        Write-Host "Creating Home DIR"
        $Results = Create-StudentHomeDir -Student $NewStudent
        Write-Host $Results
        if ($Results[1]) {
            Write-Host "Created Directory: $($Results[0])"
        } else {
            Write-Host $Results[0]
        }
    }

    $error.Clear()
    try {
        $ADparam = @{
            Name                 = $NewStudent.displayname 
            DisplayName          = $NewStudent.displayname 
            SamAccountName       = $NewStudent.SamAccountName 
            Enabled              = $true
            PasswordNeverExpires = $true
            CannotChangePassword = $true
            UserPrincipalName    = $NewStudent.email
            Email                = $NewStudent.email 
            Givenname            = $NewStudent.First_Name
            Surname              = $NewStudent.Last_Name
            Path                 = $NewStudent.ou 
            ScriptPath           = $NewStudent.scriptpath 
            Description          = $NewStudent.Description 
            EmployeeNumber       = $NewStudent.GUID 
            EmployeeID           = $NewStudent.Student_Number
            homedirectory        = $NewStudent.homedirectory
            homedrive            = "H:"
            accountPassword      = $NewStudent.Password
            OtherAttributes = @{
                Pager = $NewStudent.Student_Number
            }

        }
        New-ADUser @ADparam

    }
    catch {
        Write-Host $Error
    }    

    if(!$error){

        foreach ($group in $NewStudent.adgroups) {
            Add-ADGroupMember -Identity $group -Members $NewStudent.SamAccountName
        }
        $NewStudent.ADGroups = $NewStudent.ADGroups -join ","
        if ($NewStudent.schoolid -eq $Data.School.ID.MMS) {
            $CompletedMSAccounts += $NewStudent
        }
        if ($NewStudent.schoolid -eq $Data.School.ID.GN -or
            $NewStudent.schoolid -eq $Data.School.ID.VN -or
            $NewStudent.schoolid -eq $Data.School.ID.SE){
            $CompletedEleAccounts += $NewStudent
        }
    }

}

$CompletedEleAccounts

if ($CompletedEleAccounts.Length -gt 0) {
    $ListPath ="$PSScriptRoot\Elementary-NewAccounts$(Get-Date -format MM.dd.yyyy.hh.mm).csv"
    $CompletedEleAccounts | Select-Object -Property @{Name = "First Name"; Expression = {$_.First_Name}},
    @{Name = "Last Name"; Expression = {$_.Last_Name}},
    @{Name = "Birthday"; Expression = {Get-Date $_.DOB -Format MM/dd/yyyy}},
    @{Name = "Username"; Expression = {$_.SamAccountName}},
    @{Name = "E-Mail Address"; Expression = {$_.Email}},
    @{Name = "Password"; Expression = {$_.PasswordAsPlainText}},
    @{Name = "Printing Code"; Expression = {$_.student_number}} | ConvertTo-CSV -NoTypeInformation | Out-File $ListPath
    
    Send-NewUserEmails -recipentList $Data.Notification.Elementary -attachment $ListPath
    
    Write-Host "Send Elementary Email"
}

$CompletedMSAccounts

if ($CompletedMSAccounts.Length -gt 0) {
    $ListPath = "$PSScriptRoot\MMS-NewAccounts$(Get-Date -format MM.dd.yyyy.hh.mm).csv"
    $CompletedMSAccounts | Select-Object -Property @{Name = "First Name"; Expression = {$_.First_Name}},
    @{Name = "Last Name"; Expression = {$_.Last_Name}},
    @{Name = "Birthday"; Expression = {Get-Date $_.DOB -Format MM/dd/yyyy}},
    @{Name = "Username"; Expression = {$_.SamAccountName}},
    @{Name = "E-Mail Address"; Expression = {$_.Email}},
    @{Name = "Password"; Expression = {$_.PasswordAsPlainText}},
    @{Name = "Printing Code"; Expression = {$_.student_number}} | ConvertTo-CSV -NoTypeInformation | Out-File $ListPath
    Send-NewUserEmails -recipentList $Data.Notification.MiddleSchool -attachment $ListPath
    Write-Host "Send MMS Email"

}