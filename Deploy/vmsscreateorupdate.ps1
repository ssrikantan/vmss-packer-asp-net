#more changes to script
#.\vmsscreateorupdate.ps1 CreateOrUpdateScaleSet -loc 'Southeast asia' -rgname 'autoweb' -imageurl "https://packervmssimages.blob.core.windows.net/system/Microsoft.Compute/Images/vsts-buildimagetask/20170618.2-osDisk.86e63cf7-10b1-4ea1-b3ae-69fe1d572b03.vhd"
param([string]$loc, [string]$rgname,[string]$imageurl)
	#param([string]$loc, [string]$rgname,[string]$imageurl)
	#$loc = 'Southeast asia';
	#$rgname = 'autoweb';
	#$imageurl = "https://packervmssimages.blob.core.windows.net/system/Microsoft.Compute/Images/vsts-buildimagetask/20170618.2-osDisk.86e63cf7-10b1-4ea1-b3ae-69fe1d572b03.vhd"
	$vmssName = 'vmss' + $rgname
	$oldornew = "old"
Try
{
	Write-Output "Create or Update Scale set triggered for vmss: $vmssName , location : $loc , custom image url $imageurl"
    $vmss = Get-AzureRmVmss -ResourceGroupName $rgname -VMScaleSetName $vmssName

    Write-Output "retrieved Scale Set $vmssName ....."
    # set the new version in the model data
    $vmss.virtualMachineProfile.storageProfile.osDisk.image.uri=$imageurl
    # update the virtual machine scale set model
    Try
    {
        Update-AzureRmVmss -ResourceGroupName $rgname -Name $vmssName -VirtualMachineScaleSet $vmss
        Write-Output "updated Scale Set $vmssName with the new custom image....."
    }
    Catch
    {
        Write-Output "Error updating Scale Set $vmssName with the new custom image....."
    }
}
Catch
{
    Write-Output "Scale set does not exist, creating new ....."
    Write-Output "Preparing to create new Scale Set Location: $loc , Resource Group Name: $rgname , Custom Image URL: $imageurl"

	New-AzureRmResourceGroup -Name $rgname -Location $loc -Force;

	$subnetName = 'subnet1'
	$subnet = New-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.0.0/24";
	Write-Output "Created Subnet ....."

	$vnet = New-AzureRmVirtualNetwork -Force -Name ('vnet' + $rgname) -ResourceGroupName $rgname -Location $loc -AddressPrefix "10.0.0.0/16" -Subnet $subnet;
	$vnet = Get-AzureRmVirtualNetwork -Name ('vnet' + $rgname) -ResourceGroupName $rgname;
	Write-Output "Created VNet  ....."

	# In this case assume the new subnet is the only one
	$subnetId = $vnet.Subnets[0].Id;

	$pubip = New-AzureRmPublicIpAddress -Force -Name ('pubip' + $rgname) -ResourceGroupName $rgname -Location $loc -AllocationMethod Dynamic -DomainNameLabel ('pubip' + $rgname);
	$pubip = Get-AzureRmPublicIpAddress -Name ('pubip' + $rgname) -ResourceGroupName $rgname;
	Write-Output "Created Public IP Address .....  "

	$frontendName = 'fe' + $rgname
	$backendAddressPoolName = 'bepool' + $rgname
	$probeName = 'vmssprobe' + $rgname
	$inboundNatPoolName = 'innatpool' + $rgname
	$lbruleName = 'HTTP'
	$lbName = 'vmsslb' + $rgname

	# Bind Public IP to Load Balancer
	$frontend = New-AzureRmLoadBalancerFrontendIpConfig -Name $frontendName -PublicIpAddress $pubip

	$backendAddressPool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $backendAddressPoolName

	$probe = New-AzureRmLoadBalancerProbeConfig -Name $probeName -RequestPath '/' -Protocol http -Port 80 -IntervalInSeconds 15 -ProbeCount 2

	$frontendpoolrangestart = 3360
	$frontendpoolrangeend = 3370
	$backendvmport = 3389
	$inboundNatPool = New-AzureRmLoadBalancerInboundNatPoolConfig -Name $inboundNatPoolName -FrontendIPConfigurationId `
	$frontend.Id -Protocol Tcp -FrontendPortRangeStart $frontendpoolrangestart -FrontendPortRangeEnd $frontendpoolrangeend -BackendPort $backendvmport;


	$protocol = 'Tcp'
	$feLBPort = 80
	$beLBPort = 80

	$lbrule = New-AzureRmLoadBalancerRuleConfig -Name $lbruleName `
	-FrontendIPConfiguration $frontend -BackendAddressPool $backendAddressPool `
	-Probe $probe -Protocol $protocol -FrontendPort $feLBPort -BackendPort $beLBPort 

	$actualLb = New-AzureRmLoadBalancer -Name $lbName -ResourceGroupName $rgname -Location $loc `
	-FrontendIpConfiguration $frontend -BackendAddressPool $backendAddressPool `
	-Probe $probe -LoadBalancingRule $lbrule -InboundNatPool $inboundNatPool -Verbose;

	$expectedLb = Get-AzureRmLoadBalancer -Name $lbName -ResourceGroupName $rgname
	Write-Output "Created Load Balancer .....  "



	## specify VMSS specific details
	$adminUsername = 'onepageradmin';
	$adminPassword = "Pass@word123";

	$PublisherName = 'MicrosoftWindowsServer'
	$Offer         = 'WindowsServer'
	$Sku          = '2012-R2-Datacenter'
	$Version       = 'latest'
	$vmNamePrefix = 'winvmss'

	###add an extension
	$extname = 'BGInfo';
	$publisher = 'Microsoft.Compute';
	$exttype = 'BGInfo';
	$extver = '2.1';


	$ipCfg = New-AzureRmVmssIPConfig -Name 'nic' `
	-LoadBalancerInboundNatPoolsId $actualLb.InboundNatPools[0].Id `
	-LoadBalancerBackendAddressPoolsId $actualLb.BackendAddressPools[0].Id `
	-SubnetId $subnetId;


	# Specify number of nodes
	$numberofnodes = 2

	#    Set-AzureRmVmssStorageProfile -Image "https://packervmssimages.blob.core.windows.net/system/Microsoft.Compute/Images/vsts-buildimagetask/20170618.2-osDisk.86e63cf7-10b1-4ea1-b3ae-69fe1d572b03.vhd" -OsDiskOsType Windows -Name "vmssosdk"  `

	$vmss = New-AzureRmVmssConfig -Location $loc -SkuCapacity $numberofnodes -SkuName 'Standard_D2' -UpgradePolicyMode 'automatic' `
		| Add-AzureRmVmssNetworkInterfaceConfiguration -Name $subnetName -Primary $true -IPConfiguration $ipCfg `
		| Set-AzureRmVmssOSProfile -ComputerNamePrefix $vmNamePrefix -AdminUsername $adminUsername -AdminPassword $adminPassword `
		| Set-AzureRmVmssStorageProfile -Image $imageurl -OsDiskOsType Windows -Name "vmssosdk"

	New-AzureRmVmss -ResourceGroupName $rgname -Name $vmssName -VirtualMachineScaleSet $vmss -Verbose;

	Write-Output "Created Scale Set using the custom image "
}  # End of catch block






