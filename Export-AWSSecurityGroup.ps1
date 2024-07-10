<#
    Script Name          - Export-AWSSecurityGroup.ps1
    Type                 - Function/CMDLET
    Date Written         - 03/04/2022
    Author               - Jeff Kuhner, Mac Sauceda, Gene Smolburd
    License              - GNU (General Public License)
    Usage                - Export-AWSSecurityGroup [-FilePath] <string> [-GroupID] <string> [-Region] <string>
    Parameters:
        FilePath         - Path to the CSV file exported from AWS Console.
        GroupID          - AWS GroupID for the Security Group to be exported.
        Region           - AWS Region that this is being applied to.

    Description          - This script adds a PowerShell CMDLET that Creates a .CSV file which describes an AWS Security Group, 
                           and the Ingress and Egress Rules that it contains.
    
    Requirements         - This script will work from Windows, Mac, or Linux with PowerShell Core 6 or better installed.
                           It also requires the AWS PowerShell Module installed and configured in order to function properly.
    Usage                - This is a function.  Run it in a powershell session and then the CMDLET will be available to use.  Can also be added to 
                            your Powershell Profile as noted here:
                            https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.4
#>

Function Export-AWSSecurityGroup
{
    [CmdletBinding()]

    Param
    (
        #Enter the path and file name at which to save the .CSV file. 
        #works on Windows + ',' + Mac + ',' +  and Linux with Powershell Core as long as the path is valid for the operating system.
        [Parameter(Mandatory=$True)]
        [String]$FilePath,
        #AWS GroupID for the Security Group you want to export. Get this form the AWS Console or CLI
        [Parameter(Mandatory=$True)]
        [String]$GroupID,

        #AWS Region where the Security Group is located.
        [Parameter(Mandatory=$True)]
        [String]$Region
    )

    Begin
    {
        #Get the properties of the Security Group that is being exported.
        $SecGroup = Get-EC2SecurityGroup -GroupId $GroupID -Region $Region
        #Setup the header for the .CSV file that is being created.
        $ExportData = "Type,IpProtocol,FromPort,ToPort,IpRanges,IPDescription,UserIdGroupPairs,UIDDescription"
        #Test if the file exists along the path entered.  If it does, halt execution and show the user a warning. Otherwise, create the file and add the column headers to it.
        if (Test-path -Path $FilePath)
        {
            Write-host "File already exists.  Please rename, delete, or move the file or specify a different filename or path." -ForegroundColor Yellow
            $ExitFunction = $True
        } else 
        {
        Add-Content  -Path $FilePath -Value $ExportData 
        }
        if ($ExitFunction)
        {
            Return
        }
   }

   Process
   {
        #Process the Ingress rules first
        foreach ($IngressRule in $SecGroup.ipPermissions)
        {
            if ($IngressRule.Ipv4Ranges.count -eq 1)
            {
                $IngressData = "Ingress" + ',' + [String]$IngressRule.IpProtocol + ',' + [String]$IngressRule.FromPort + ',' + [String]$IngressRule.ToPort + ',' + [String]$IngressRule.Ipv4Ranges.CidrIp + ',' + [String]$IngressRule.Ipv4Ranges.Description + ',' + [String]$IngressRule.UserIdGroupPairs.GroupID + ',' + [String]$IngressRule.UserIdGroupPairs.Description
                Add-Content -Path $FilePath -Value $IngressData
            } else 
            {
                foreach ($IPAddress in $IngressRule.Ipv4Ranges)
                {
                    $IngressData = "Ingress" + ',' + [String]$IngressRule.IpProtocol + ',' + [String]$IngressRule.FromPort + ',' + [String]$IngressRule.ToPort + ',' + [String]$IPAddress.CidrIp + ',' + [String]$IPAddress.Description + ',' + [String]$IngressRule.UserIdGroupPairs.GroupID + ',' + [String]$IngressRule.UserIdGroupPairs.Description
                    Add-Content -Path $FilePath -Value $IngressData
                }   
            }
        }
        #Now process the Egress rules
        foreach ($EgressRule in $SecGroup.IpPermissionsEgress)
        {
            $EgressData = "Egress" + ',' + [String]$EgressRule.IpProtocol + ',' + [String]$EgressRule.FromPort + ',' + [String]$EgressRule.ToPort + ',' + [String]$EgressRule.Ipv4Ranges.CidrIp + ',' + [String]$EgressRule.Ipv4Ranges.Description + ',' + [String]$EgressRule.UserIdGroupPairs.GroupID + ',' + [String]$EgressRule.UserIdGroupPairs.Description
            Add-Content -Path $FilePath -Value $EgressData
        }

   }


} #Function End