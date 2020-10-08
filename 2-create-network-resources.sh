#!/bin/bash

source ./demo-vars.sh

# Create a virtual network to hold provisioned resources
az network vnet create --address-prefixes $VNET_ADDRESS \
  --name $VNET_NAME --resource-group $RESOURCE_GROUP

az network vnet subnet create \
    --address-prefixes $SUBNET_PRIMARY_ADDRESS \
    --name $SUBNET_PRIMARY_NAME \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME



