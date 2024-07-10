<#************************************************************
    Script Name:  FInd Unused SecurityGroups.ps1
    Written by: Jeff Kuhner
    Written on: 07/01/2024
    Description: Gets a list of security groups from the configured regions and then checks to see if they are attached to an EC2 instance.
    If no EC2 instance is found, the group is added to the list and reported.  The script can be set to attmept to delete the group as well
    by uncommenting the line noted below.
    Last Update by: Jeff Kuhner
    Last Update on: 07/09/2024
#>

# Initialize the counter to Zero.
$Total = 0

# Set regions that are to be checked.  More reagions can be addded as needed.  Regions should be in a comma delimeted list as below.
$Regionlist = "us-west-1","us-west-2"

# Loop through the regions and check the security groups against all EC2 instances in the region.
foreach ($Region in $Regionlist) 
    {
        # Set the region the code is looking at currently.
        Set-DefaultAWSRegion -Region $Region

        # Write out the current region and some formatting.
        Write-host $Region
        Write-Host '======================================'

        # Get the security groups for the region.
        $GroupList = Get-EC2SecurityGroup

        # Loop through the list of groups.
        foreach ($Group in $GroupList)
            {
                # Look at the group to see if any ENI (Elastic Network Interface) objects are in the group.
                $NetCheck = (Get-EC2NetworkInterface).Groups | Where-Object -FilterScript {$PSItem.GroupId -match $Group.GroupId}
                
                # Check to see if at least 1 ENI is present.
                If ($NetCheck.Count -eq 0)
                    {
                        # If the group has Zero ENIs attached, check to see if the group is a DEFAULT group for a VPC
                        If ($Group.Groupname -ne 'default')
                            {
                                # If the group is not a DEFAULT VPC group, note it and report.
                                # If you want to delete the group as well, un comment the line below.
                                # Remove-EC2SecurityGroup -GroupID $Group.GroupID -Force
                                Write-Host $Group.GroupID "," #$Group.GroupName
                                
                                # Increment the counter for the number of groups found that are not attached to an ENI
                                $Total=$Total + 1
                            }
                    }
            }
    }

# Report findings to the screen.  
Write-Host ' '
Write-Host 'Total: '$Total -BackgroundColor DarkGreen -ForegroundColor White