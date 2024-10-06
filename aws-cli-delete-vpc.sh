#!/bin/bash
#**************************************************************************
# Script para la Eliminación Segura de Recursos AWS
#**************************************************************************

AWS_REGION="us-east-1"
RESOURCE_FILE="aws_resources.txt"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color

# Leer IDs de los recursos desde un archivo
function read_resource_id() {
    echo $(grep "$1" $RESOURCE_FILE | cut -d ':' -f2 | xargs)
}

# Función para eliminar un recurso con manejo de excepciones
function delete_resource() {
    local description="$1"
    local command="$2"
    echo -e "${YELLOW}Eliminando ${description}...${NC}"
    if ! eval $command; then
        echo -e "${RED}Error eliminando ${description}.${NC}"
        return 1
    else
        echo -e "${GREEN}${description} eliminado correctamente.${NC}"
        return 0
    fi
}

# Variables de recursos
VPC_ID=$(read_resource_id "VPC_ID")
SUBNET_PUBLIC_ID=$(read_resource_id "SUBNET_PUBLIC_ID")
SUBNET_PRIVATE_ID=$(read_resource_id "SUBNET_PRIVATE_ID")
IGW_ID=$(read_resource_id "IGW_ID")
ROUTE_TABLE_PUBLIC_ID=$(read_resource_id "ROUTE_TABLE_ID")
ROUTE_TABLE_PRIVATE_ID=$(read_resource_id "ROUTE_TABLE_ID") # Asumiendo que existe
NAT_GW_ID=$(read_resource_id "NAT_GW_ID")
EIP_ALLOC_ID=$(read_resource_id "EIP_ALLOC_ID")

# Paso 1: Desasociar Subredes de las Tablas de Enrutamiento
delete_resource "desasociación de Subred Pública de la Tabla de Enrutamiento" "aws ec2 disassociate-route-table --association-id $(aws ec2 describe-route-tables --route-table-id $ROUTE_TABLE_PUBLIC_ID --query 'RouteTables[].Associations[?SubnetId==`$SUBNET_PUBLIC_ID`].RouteTableAssociationId' --output text --region $AWS_REGION) --region $AWS_REGION"
delete_resource "desasociación de Subred Privada de la Tabla de Enrutamiento" "aws ec2 disassociate-route-table --association-id $(aws ec2 describe-route-tables --route-table-id $ROUTE_TABLE_PRIVATE_ID --query 'RouteTables[].Associations[?SubnetId==`$SUBNET_PRIVATE_ID`].RouteTableAssociationId' --output text --region $AWS_REGION) --region $AWS_REGION"

# Paso 2: Eliminar NAT Gateway
delete_resource "NAT Gateway" "aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID --region $AWS_REGION"
aws ec2 wait nat-gateway-deleted --nat-gateway-id $NAT_GW_ID --region $AWS_REGION

# Paso 3: Liberar la Dirección IP Elástica
delete_resource "Elastic IP" "aws ec2 release-address --allocation-id $EIP_ALLOC_ID --region $AWS_REGION"

# Paso 4: Eliminar Tablas de Enrutamiento
delete_resource "Tabla de Enrutamiento Pública" "aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_PUBLIC_ID --region $AWS_REGION"
delete_resource "Tabla de Enrutamiento Privada" "aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_PRIVATE_ID --region $AWS_REGION"

# Paso 5: Desasociar y Eliminar Internet Gateway
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $AWS_REGION
delete_resource "Internet Gateway" "aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $AWS_REGION"

# Paso 6: Eliminar Subredes
delete_resource "Subred Pública" "aws ec2 delete-subnet --subnet-id $SUBNET_PUBLIC_ID --region $AWS_REGION"
delete_resource "Subred Privada" "aws ec2 delete-subnet --subnet-id $SUBNET_PRIVATE_ID --region $AWS_REGION"

# Paso 7: Eliminar la VPC
delete_resource "VPC" "aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION"

echo -e "${GREEN}Todos los recursos han sido eliminados.${NC}"
