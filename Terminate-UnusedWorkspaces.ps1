<#
    Script Name:    Terminate-UnusedWorkspaces.ps1
    Author:         Jeff Kuhner
    Date:           01/11/2024
    Last Update:    01/11/2024
    Description:    This script gets all current workspaces and checks to see the last date they were accessed by the user.  If that date is 30 days
                    or greater in the past, the machine is marked for Termination.  Machines that have never been logged into are listed but not removed
                    as they need to be manually checked in case they are for a user that has not onboarded yet.  Also left are workspaces for IT
                    personell.
    Compatability:  This script will run on Windows Powershell or Powershell Core for Windows, MacOS, and Linux.
    Required Module:Any of the following - AWS.Tools.WorkSpaces, AWSPowerShell.NetCore and AWSPowerShell
#>

#   Get a current list of Workspaces from Amazon
$WorkSpaces = get-wksWorkspaces

#   Setup an array with a list of IT user accounts that might have a Workspace assigned to them.  This list needs to be maintained as personell changes
$IT = @(
            "tpuppo"
            "Joshualincecum"
            "afleming"
            "bulloa"
            "hmendoza"
            "jasonramirez"
            "sgoodin"
            "jkuhner"
            "msauceda"
            "rnichols"
            "akeyser"
            "jkuhner-admin"
            "afleming-admin9385"
            "jramirez-admin9540"
            "jlincecum-admin8675"
            "sgoodin-admin"
            "tpuppo-admin1254"
            "akeyser-Admin6898"
            "bulloa-Admin6638"
            "hmendoza-Admin5978"
            "rnichols-Admin1133"
        )

#   Setup an empty array to hold the Unsed Workspaces
$UnusedWKSP = @()

#   Loop through the workspaces that we gathered earlier to check them one by one
foreach ($WorkSpace in $Workspaces)
{
    #   Pull the current status of the workspace that is being looked at during this loop
    $WorkSpaceCon = Get-WKSWorkspacesConnectionStatus -WorkspaceId $Workspace.WorkspaceId

    #   Check the LastKnownConnectionTimestamp property to see if the workspace device has been accessed within the last 30 days
    if ($WorkSpaceCon.LastKnownUserConnectionTimestamp -le (get-date).AddDays(-30))
    {
        #   If the workspace has not been accessed in the last 30 days, has it ever been accessed?
        If ($WorkSpaceCon.LastKnownUserConnectionTimestamp -eq "01/01/0001 00:00:00")
        {
            #   If it has not ever been accessed, print the information to the screen for manual investigation
            $Output = $Workspace.UserName + "," + $WorkSpaceCon.LastKnownUserConnectionTimestamp
            Write-host "Workspace " , $Output , " has never been logged into."
        }else 
        {
            #   If it has not been accessed within the last 30 days but it has been used in the past, add it to the array of unused devices.
            #   We are collecting Username, Last Used TIme, and WorkspaceID
            $UnusedWKSP += @([PSCustomObject]@{
                UserName = $Workspace.UserName ; LastKnownUserConnectionTimestamp = $WorkSpaceCon.LastKnownUserConnectionTimestamp ; WorkspaceID = $Workspace.WorkspaceId
            })
        }

    }
}

#   Now loop through all of the Worksapces that were marked as unused in the last 30 days
foreach ($Unused in $UnusedWKSP)
{
    #   Check to see if the user of the Workspace is IT personell.  If so, skip it.  If not, terminate it
    if (!($Unused.UserName -in $IT))
    {
        #Remove the workspace from our account
        Remove-WKSWorkspace -WorkspaceId $Unused.WorkspaceId -Force

        #   Confirm on screen that the device was removed
        Write-Host "Workspace for " , $Unused.UserName , " has been Terminated!" -ForegroundColor DarkRed
    }
}#End
