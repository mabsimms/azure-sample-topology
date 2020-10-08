#!/bin/bash

# Now that we have a very very basic configuration, let's go through some 
# resiliency options.

# My VMSS instances are spread across fault domains, which represent physical
# (power circuits, top-of-rack switches, network segments) fault boundaries 

# If I want additional isolation I can spread these instances across 
# availability zones, which represent logical collections of data centers
# with greater degrees of physical isolation (separate DCs, separate power/network
# paths) and logical isolation (fully independent updater boundaries).

# VMSS spreading across availablity zones is still a destructive activity, so 
# let's destroy
az vmss delete --name $VMSS_CONTENT_NAME \
    --resource-group $RESOURCE_GROUP

# Create a zone enabled VM scale set to host a simple static content web server
VMSS_LB_ID=$(az network lb show --name $VMSS_LB_NAME --resource-group $RESOURCE_GROUP | jq -r .id)

az vmss create --name $VMSS_CONTENT_NAME \
    --resource-group $RESOURCE_GROUP \
    --computer-name-prefix $VMSS_CONTENT_NAME_PREFIX \
    --custom-data vmss-content.txt \
    --image $VMSS_IMAGE \
    --instance-count $VMSS_CONTENT_INSTANCE_COUNT \
    --location $LOCATION_PRIMARY \
    --orchestration-mode ScaleSetVM \
    --platform-fault-domain-count 5 \
    --scale-in-policy NewestVM \
    --vm-sku $VMSS_SIZE \
    --authentication-type ssh \
    --ssh-key-values id_rsa.pub \
    --accelerated-networking true \
    --vnet-name $VNET_NAME \
    --subnet $SUBNET_PRIMARY_NAME \
    --public-ip-address "" \
    --lb $VMSS_LB_ID \
    --nsg vmss-nsg \
    --zones 1 2 3

# Let's have a look at how that turned out
az vmss get-instance-view --resource-group $RESOURCE_GROUP --name $VMSS_CONTENT_NAME
az vmss list-instances --resource-group $RESOURCE_GROUP --name $VMSS_CONTENT_NAME
az vmss list-instances --resource-group $RESOURCE_GROUP --name $VMSS_CONTENT_NAME | jq '.[] | .name, .zones, .osDisk.managedDisk.storageAccountType'

# And is it working?
