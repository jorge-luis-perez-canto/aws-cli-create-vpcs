#!/bin/bash
#**************************************************************************
# Script mejorado para la Eliminación de una VPC en AWS y sus recursos asociados
#**************************************************************************

AWS_REGION="us-east-1"
RESOURCE_FILE="aws_resources.txt"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color

# Función para leer identificadores de recursos del archivo
function read_resource_id() {
    grep "$1" $RESOURCE_FILE | cut -d ':' -f2 | xargs
}

# Función para manejar la eliminación de recursos
function delete_resource() {
    local resource_type="$1"
    local resource_id="$2"
    local command="$3"
    echo -e "${YELLOW}Intentando eliminar ${resource_type} con ID ${resource_id}...${NC}"
    if ! eval $command; then
        echo -e "${RED}Error eliminando ${resource_type} con ID ${resource_id}. Verificando...${NC}"
        return 1
    else
        echo -e "${GREEN}${resource_type} con ID ${resource_id} eliminado correctamente.${NC}"
        return 0
    fi
}

# Desasociar Subredes de Tablas de Enrutamiento
ASSOC_PUBLIC_ID=$(aws ec2 describe-route-tables --route-table-id $(read_resource_id "ROUTE_TABLE_ID") --query "RouteTables[].Associations[?SubnetId=='$(read_resource_id SUBNET_PUBLIC_ID)'].RouteTableAssociationId" --output text --region $AWS_REGION)
ASSOC_PRIVATE_ID=$(aws ec2 describe-route-tables --route-table-id $(read_resource_id "ROUTE_TABLE_ID") --query "RouteTables[].Associations[?SubnetId=='$(read_resource_id SUBNET_PRIVATE_ID)'].RouteTableAssociationId" --output text --region $AWS_REGION)

delete_resource "Asociación de Subred Pública" $ASSOC_PUBLIC_ID "aws ec2 disassociate-route-table --association-id $ASSOC_PUBLIC_ID --region $AWS_REGION"
delete_resource "Asociación de Subred Privada" $ASSOC_PRIVATE_ID "aws ec2 disassociate-route-table --association-id $ASSOC_PRIVATE_ID --region $AWS_REGION"

# Eliminar NAT Gateway
NAT_GW_ID=$(read_resource_id "NAT_GW_ID")
delete_resource "NAT Gateway" $NAT_GW_ID "aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID --region $AWS_REGION && aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_GW_ID --region $AWS_REGION"

# Liberar Elastic IP
EIP_ALLOC_ID=$(read_resource_id "EIP_ALLOC_ID")
delete_resource "Elastic IP" $EIP_ALLOC_ID "aws ec2 release-address --allocation-id $EIP_ALLOC_ID --region $AWS_REGION"

# Eliminar Subredes
SUBNET_PUBLIC_ID=$(read_resource_id "SUBNET_PUBLIC_ID")
SUBNET_PRIVATE_ID=$(read_resource_id "SUBNET_PRIVATE_ID")
delete_resource "Subred Pública" $SUBNET_PUBLIC_ID "aws ec2 delete-subnet --subnet-id $SUBNET_PUBLIC_ID --region $AWS_REGION"
delete_resource "Subred Privada" $SUBNET_PRIVATE_ID "aws ec2 delete-subnet --subnet-id $SUBNET_PRIVATE_ID --region $AWS_REGION"

# Desasociar y eliminar Internet Gateway
IGW_ID=$(read_resource_id "IGW_ID")
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $(read_resource_id "VPC_ID") --region $AWS_REGION
delete_resource "Internet Gateway" $IGW_ID "aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $AWS_REGION"

# Eliminar Tablas de Rutas
ROUTE_TABLE_ID=$(read_resource_id "ROUTE_TABLE_ID")
delete_resource "Tabla de Rutas" $ROUTE_TABLE_ID "aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION"

# Eliminar VPC
VPC_ID=$(read_resource_id "VPC_ID")
delete_resource "VPC" $VPC_ID "aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION"

echo -e "${GREEN}Proceso de eliminación completado.${NC}"
