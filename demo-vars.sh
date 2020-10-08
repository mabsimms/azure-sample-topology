#!/bin/bash

SSH_KEY_PATH=$HOME/.ssh/id_rsa.pub

# Set up the stock variables for the walkthrough
RESOURCE_GROUP=mastest-rg
LOCATION_PRIMARY=eastus

# Network variables
VNET_ADDRESS=10.0.0.0/16
VNET_NAME=demo-vnet
SUBNET_PRIMARY_ADDRESS=10.0.1.0/24
SUBNET_PRIMARY_NAME=vmsubnet
PUBLIC_IP_NAME=mascontent-pip
VMSS_LB_NAME=mascontent-lb

# Solo VM
VM_NAME=solovm
VM_IMAGE=Canonical:UbuntuServer:18.04-LTS:latest
VM_SIZE=Standard_DS3_v2
VM_IP=10.0.1.5

VMSS_IMAGE=Canonical:UbuntuServer:18.04-LTS:latest
VMSS_SIZE=Standard_DS3_v2

# VMSS - simple content server
VMSS_CONTENT_NAME=content-vmss
VMSS_CONTENT_NAME_PREFIX=content

VMSS_CONTENT_INSTANCE_COUNT=2
