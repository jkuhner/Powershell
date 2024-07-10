<#
    Script Name          - Import-AWSSecurityGroup.ps1
    Type                 - Function/CMDLET
    Date Written         - 02/21/2022
    Author               - Jeff Kuhner
    License              - GNU (General Public License)
    Usage                - Import-AWSSecurityGroup [-FilePath] <string> [-GroupName] <string> [-GroupDescription] <string>
                           [-VPCid] <string> [-Region] <string> [-OutputPath] <string> [<CommonParameters>]
    Parameters:
        FilePath         - Path to the CSV file exported from AWS Console.
        GroupName        - Name of new Security group to create in AWS.  Must follow AWS naming constraints.
        GroupDescription - Description for the security group being created.
        VPCid            - VPCID for the VPC that the group is being created in.
        Region           - AWS Region that this is being applied to.
        OutPutPath       - Path to the exception list that the script will generate if needed.

    Description          - This script adds a PowerShell CMDLET that takes a .CSV file which describes a Security Group, 
                           and the Ingress and Egress Rules that it contains and creates the group in the target VPC/Region.
                           If the Security Group is being migrated from one region to another, and any of its rules 
                           reference another security group rather than an IP CIDR block, that entry will fail and an 
                           exception list will be generated.  This is a limitation of AWS where Security groups from one 
                           region cannot be targets for security groups in another region.
    
    Requirements         - This script will work from Windows, Mac, or Linux with PowerShell Core 6 or better installed.
                           It also requires the AWS PowerShell Module installed and configured in order to function properly.
    Usage                - This is a function.  Run it in a powershell session and then the CMDLET will be available to use.  Can also be added to 
                            your Powershell Profile as noted here:
                            https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.4

#>

Function Import-AWSSecurityGroup
{
    [CmdletBinding()]

    Param
    (
        #Enter the path to the .CSV file you optained from the AWS Console that describes the Security Group you are migrating.
        #Works on Windows,Mac, and Linux with Powershell Core as long as the path is valid.
        [Parameter(Mandatory=$True)]
        [String]$FilePath,

        #Name of new Security group you want to create.  Must adhere to the AWS rules for Security Group names.
        [Parameter(Mandatory=$True)]
        [String]$GroupName,

        #Description for the Security Group.  Requred by AWS but can be as short as 1 character.
        [Parameter(Mandatory=$True)]
        [String]$GroupDescription,

        #VPC ID number of the VPC into which this Security Group will be created.
        [Parameter(Mandatory=$True)]
        [String]$VPCid,

        #AWS Region into which this Scecurity Group will be created.
        [Parameter(Mandatory=$True)]
        [String]$Region,

        #Path and filename where you would like the exception list, if any, to be saved as a .CSV.
        [Parameter(Mandatory=$True)]
        [string]$OutputPath
    )

    Begin
    {
        #Import the .CSV file that has all of the Ingress Rules to be applied to the Security Group
        $import = import-csv $FilePath

        #Ceate the new Security Group in the specified VPC and Region
        $GroupID = New-EC2SecurityGroup -GroupName $GroupName -GroupDescription $GroupDescription -vpcid $VPCid -region $Region
        
        #Add a tag for the Name of the Security Group.  This currently uses the $GroupName parameter but could have a new
        #parameter created if this is desired.
        New-EC2Tag -resourceID $GroupID -Tag @{Key="Name";Value=$GroupName} -region $Region
    }
    
    Process
    {
        #Loop through the entries that were imported one-by-one so we can format each line and add it to the rules in the group.
        foreach($obj in $import)
        {
            #There are two differnt file layouts depneding on where the .CSV file was created.
            #If the AWS Console was used, the IpDescription and UIDDescription properties will not exist and so the first block of code will run.
            #If they are present, then the file was created using the Export-AWSSecurityGroup function and the second block will run.
            If (!($obj.IpDescription -or $obj.UIDDescription))
            {
                #These two TRY statemnts attempt to format data obtained form the AWS Console Export option.
                Try 
                {
                    #If present, format the data for the Security Group that is the target of the rule currently being processed.
                    $GroupData = $obj.UserIDGroupPairs
                    #Split the Security Group ID from the description.
                    $GroupData = $GroupData.split(' ',2)
                    $IngressGroup = $GroupData[0]
                    $IngressGroupDesc = $GroupData[1]   
                }
                Catch 
                {
                }
                
                Try 
                {
                    #If present, format the data for the CIDR block that is the target of the rule currently being processed.
                    $IPData = $obj.ipranges
                    #Split the CIDR block form the deskcription.
                    $IPData = $IPData.split(' ',2)
                    $IngressIP = $IPData[0]
                    $IngressDesc = $IPData[1]
                }
                Catch 
                {
                }
            } else 
            {
                #This code is for formatting data obtained from the Export-AWSSecurityGroup function.
                #Format the data for the Security Group or IP that is the target of the rule currently being processed.
                $IngressGroup = $obj.UserIDGroupPairs
                $IngressGroupDesc = $obj.UIDDescription
                $IngressIP = $obj.ipranges
                $IngressDesc = $obj.IpDescription
                       
            }
        
            #If the data includes a Security Group target, this block will attempt to add that rule into the group.
            if ($IngressGroup -like "sg-*")
            {
                $SecurityGroup = New-Object Amazon.EC2.Model.UserIdGroupPair
                $SecurityGroup.GroupID = $IngressGroup
                $SecurityGroup.UserId = $GroupID
                $SecurityGroup.Description = $IngressGroupDesc
                $ipPermissions = New-Object Amazon.EC2.Model.IpPermission
                $ipPermissions.IpProtocol = $obj.ipprotocol
                $ipPermissions.FromPort = $obj.fromport
                $ipPermissions.ToPort = $obj.toport

                try 
                {
                    Grant-EC2SecurityGroupIngress -GroupID $GroupID -IpPermissions @( @{IpProtocol=$ipPermissions.IpProtocol; FromPort=$ipPermissions.FromPort; ToPort=$ipPermissions.ToPort; UserIdGroupPairs=$SecurityGroup}) -region $Region
                }
                catch 
                {
                    Export-Csv -Path $OutputPath -NoTypeInformation -InputObject $obj -Append
                }

            } else
            {
                #If no Security Group is present then add a CIDR block tartgeted rule to group instead.
                #Check to see if the entry is for an INBOUND or OUTBOUND rule
                If ($obj.Type -like "*Egress")
                {
                    #Add an Outbound rule to the Security Group
                    $cidrBlocks = New-Object -TypeName Amazon.EC2.Model.IpRange
                    $cidrBlocks.CidrIP = $IngressIP
                    $cidrBlocks.Description = $IngressDesc
                    $ipPermissions = New-Object Amazon.EC2.Model.IpPermission
                    $ipPermissions.IpProtocol = $obj.ipprotocol
                    $ipPermissions.FromPort = $obj.fromport
                    $ipPermissions.ToPort = $obj.toport
                    $ipPermissions.Ipv4Ranges = $cidrBlocks

                    try 
                    {
                        Grant-EC2SecurityGroupEgress -GroupID $GroupID -IpPermissions $ippermissions -region $Region
                    }
                    catch 
                    {
                        
                    }
                    
                } else 
                {
                    #Add an Inbound rule to the Security Group
                    $cidrBlocks = New-Object -TypeName Amazon.EC2.Model.IpRange
                    $cidrBlocks.CidrIP = $IngressIP
                    $cidrBlocks.Description = $IngressDesc
                    $ipPermissions = New-Object Amazon.EC2.Model.IpPermission
                    $ipPermissions.IpProtocol = $obj.ipprotocol
                    $ipPermissions.FromPort = $obj.fromport
                    $ipPermissions.ToPort = $obj.toport
                    $ipPermissions.Ipv4Ranges = $cidrBlocks
                    Grant-EC2SecurityGroupIngress -GroupID $GroupID -IpPermissions $ippermissions -region $Region
                }
            }
        }
    } 
 } 