#!/bin/bash
set -x #echo on

declare resourceGroupName="CustomerName"
declare azureLocation="northeurope"
declare customerName="CustomerName"
declare vmName1="vm1"
declare vmName2="vm2"
declare sshIdentityFile="~/.ssh/id_rsa.pub"

#az login

az group create -n $resourceGroupName -l $azureLocation

# Create Virtual Network

echo "Creating Virtual Network"
az network vnet create \
--name $customerName \
--resource-group $resourceGroupName \
--location $azureLocation \
--address-prefix 10.1.0.0/24 \
--subnet-name FrontEnd \
--subnet-prefix 10.1.0.0/24

# Create the first VM

echo "Create new VM"
az vm create --name $vmName1 \
--resource-group $resourceGroupName \
--image UbuntuLTS \
--authentication-type ssh \
--admin-username olavt \
--ssh-key-value ~/.ssh/id_rsa.pub \
--vnet-name $customerName \
--subnet FrontEnd

echo $publicIpAddress

# Install software

# Create custom image of VM

# Deprovision VM

# To get Public IP addresses for VM use:
publicIpAddress=$(az vm list-ip-addresses --resource-group $resourceGroupName --name $vmName1 \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" \
--out tsv)

echo $publicIpAddress

ssh olavt@$publicIpAddress << END
sudo waagent -deprovision
y
END

echo "Deallocating VM"
az vm deallocate \
--resource-group $resourceGroupName \
--name $vmName1

echo "Generalize VM"
az vm generalize \
--resource-group $resourceGroupName \
--name $vmName1

echo "Creating image from VM"
az image create \
--resource-group $resourceGroupName \
--name custom-image-1 \
--source $vmName1

# Create VM Scale Set

echo "Creating VM Scale Set"
az vmss create \
--resource-group $resourceGroupName \
--name ScaleSet \
--image custom-image-1 \
--instance-count 1 \
--public-ip-per-vm \
--authentication-type ssh \
--admin-username olavt \
--ssh-key-value ~/.ssh/id_rsa.pub \
--vnet-name $customerName \
--subnet FrontEnd

# Create the second VM

echo "Creating new VM"
az vm create --name $vmName2 \
--resource-group $resourceGroupName \
--image UbuntuLTS \
--authentication-type ssh \
--admin-username olavt \
--ssh-key-value ~/.ssh/id_rsa.pub \
--vnet-name $customerName \
--subnet FrontEnd

# Install software

# Create custom image of VM

# Deprovision VM

# To get Public IP addresses for VM use:
publicIpAddress=$(az vm list-ip-addresses --resource-group $resourceGroupName --name $vmName2 \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" \
--out tsv)

echo $publicIpAddress

ssh olavt@$publicIpAddress << END
mkdir image2
sudo waagent -deprovision
y
END

echo "Deallocating VM"
az vm deallocate \
--resource-group $resourceGroupName \
--name $vmName2

echo "Generalize VM"
az vm generalize \
--resource-group $resourceGroupName \
--name $vmName2

echo "Creating image"
az image create \
--resource-group $resourceGroupName \
--name custom-image-2 \
--source $vmName2

# Get image id of the new image

imageId=$(az image show --resource-group $resourceGroupName --name custom-image-2 \
--query "id" \
--out tsv)

# Update Scale Set with new image

echo "Update VM Scale Set with new image"
az vmss update \
--resource-group $resourceGroupName \
--name ScaleSet \
--set virtualMachineProfile.storageProfile.imageReference.id=$imageId

# Scale the Scale Set to 2 instances

az vmss scale \
--name ScaleSet  \
--resource-group $resourceGroupName \
--new-capacity 2

# To get Public IP addresses for VMs in Scale Set use:
publicIpAddresses = $(az vmss list-instance-public-ips --resource-group $resourceGroupName --name ScaleSet \
--query "[].ipAddress" \
--out tsv)

echo $publicIpAddresses

# Upgrade old instance in VM Scale Set

az vmss update-instances \
--name ScaleSet \
--resource-group $resourceGroupName \
--instance-ids 1

# Scale the Scale Set to 1 instance

az vmss scale \
--name ScaleSet  \
--resource-group $resourceGroupName \
--new-capacity 1

# To get Public IP addresses for VMs in Scale Set use:
publicIpAddresses = $(az vmss list-instance-public-ips --resource-group $resourceGroupName --name ScaleSet \
--query "[].ipAddress" \
--out tsv)

echo $publicIpAddresses
