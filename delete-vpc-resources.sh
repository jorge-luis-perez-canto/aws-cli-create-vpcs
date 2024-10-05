#!/bin/bash

# Variables
AWS_REGION="us-east-1"
VPC_ID="ID_DE_TU_VPC"
SUBNET_PUBLIC_ID="ID_DE_TU_SUBNET_PUBLICA"
SUBNET_PRIVATE_ID="ID_DE_TU_SUBNET_PRIVADA"
IGW_ID="ID_DE_TU_INTERNET_GATEWAY"
ROUTE_TABLE_ID="ID_DE_TU_TABLA_RUTAS"
NAT_GW_ID="ID_DE_TU_NAT_GATEWAY"
EIP_ALLOC_ID="ID_DE_TU_ELASTIC_IP"
MAIN_ROUTE_TABLE_ID="ID_DE_TU_TABLA_RUTAS_PRINCIPAL"

# Eliminar NAT Gateway
echo "Eliminando Puerta de Enlace NAT..."
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID --region $AWS_REGION
aws ec2 release-address --allocation-id $EIP_ALLOC_ID --region $AWS_REGION
echo "Puerta de Enlace NAT eliminada."

# Eliminar rutas a NAT Gateway
echo "Eliminando rutas a NAT Gateway..."
aws ec2 delete-route --route-table-id $MAIN_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --region $AWS_REGION

# Desasociar Tabla de Rutas
echo "Desasociando Tabla de Rutas..."
aws ec2 disassociate-route-table --association-id $(aws ec2 describe-route-tables --filters "Name=route-table-id,Values=$ROUTE_TABLE_ID" --query "RouteTables[*].Associations[*].RouteTableAssociationId" --output text --region $AWS_REGION)

# Eliminar Tabla de Rutas
echo "Eliminando Tabla de Rutas..."
aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION

# Desasociar y eliminar Internet Gateway
echo "Eliminando Puerta de Enlace de Internet..."
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $AWS_REGION
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $AWS_REGION

# Eliminar Subnets
echo "Eliminando Subredes..."
aws ec2 delete-subnet --subnet-id $SUBNET_PUBLIC_ID --region $AWS_REGION
aws ec2 delete-subnet --subnet-id $SUBNET_PRIVATE_ID --region $AWS_REGION

# Eliminar VPC
echo "Eliminando VPC..."
aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION

echo "Todos los recursos han sido eliminados."
