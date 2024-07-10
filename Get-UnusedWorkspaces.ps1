<#
    Script Name:    Get-Unused Workspaces
    Written By:     Jeff Kuhner
    Written On:     03/09/2021
    Description:    Gets a list of Workspaces from you AWS environment.  Once the list is compiled, it looks at last login date.
                    any Worksoaces that have a last login date that is more than the ADDDAYS value in th past are flagged and listed.
    Usage:          Works on Windows, Mac, and Linux in Powershell Core 6 and above.  Reguires the AWS powershell module and an AWS account
                    with permissions to access the AWS Workspaces anvironment for your organization.
#>

# Get current list of active workspaces from AWS
$WorkSpaces = get-wksWorkspaces

# Loop through the list to check the Last time it was used
foreach ($WorkSpace in $Workspaces)
{
    # Get the connection status of the current Workspace
    $WorkSpaceCon = Get-WKSWorkspacesConnectionStatus -WorkspaceId $Workspace.WorkspaceId

    # Check the LastKnownUserConnectionTimeStamp to see if it is less than 30 days ago.  If you want to check a different time,
    # then change the number in the AddDays statement below.
    if ($WorkSpaceCon.LastKnownUserConnectionTimestamp -le (get-date).AddDays(-30))
    {
        # Output the Workspaces that are found to be unused to the console.
        $Output = $Workspace.UserName + "," + $WorkSpaceCon.LastKnownUserConnectionTimestamp

        Write-host $Output   
    }
}

