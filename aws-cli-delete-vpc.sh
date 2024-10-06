#!/bin/bash
#**************************************************************************
# Script de Shell para la Eliminación de una VPC en AWS y sus recursos asociados
#**************************************************************************

AWS_REGION="us-east-1"
RESOURCE_FILE="aws_resources.txt"

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color

# Leer los IDs desde el archivo
VPC_ID=$(grep "VPC_ID" $RESOURCE_FILE | cut -d ':' -f2 | xargs)
SUBNET_PUBLIC_ID=$(grep "SUBNET_PUBLIC_ID" $RESOURCE_FILE | cut -d ':' -f2 | xargs)
SUBNET_PRIVATE_ID=$(grep "SUBNET_PRIVATE_ID" $RESOURCE_FILE | cut -d ':' -f2 | xargs)
IGW_ID=$(grep "IGW_ID" $RESOURCE_FILE | cut -d ':' -f2 | xargs)
ROUTE_TABLE_ID=$(grep "ROUTE_TABLE_ID" $RESOURCE_FILE | cut -d ':' -f2 | xargs)
ASSOC_RT_PUB_ID=$(grep "ASSOC_RT_PUB_ID" $RESOURCE_FILE | cut -d ':' -f2 | xargs)
EIP_ALLOC_ID=$(grep "EIP_ALLOC_ID" $RESOURCE_FILE | cut -d ':' -f2 | xargs)
NAT_GW_ID=$(grep "NAT_GW_ID" $RESOURCE_FILE | cut -d ':' -f2 | xargs)
MAIN_ROUTE_TABLE_ID=$(grep "MAIN_ROUTE_TABLE_ID" $RESOURCE_FILE | cut -d ':' -f2 | xargs)

# Función para eliminar recursos con manejo de errores
function delete_resource() {
    local description="$1"
    local id="$2"
    local aws_command="$3"
    echo -e "${YELLOW}Eliminando ${description} con ID ${id}...${NC}"
    if ! eval $aws_command; then
        echo -e "${RED}Error eliminando ${description} con ID ${id}.${NC}"
        return 1
    else
        echo -e "${GREEN}${description} con ID ${id} eliminado correctamente.${NC}"
        return 0
    fi
}

# Eliminar recursos en orden específico
# Desasociar Subred de la Tabla de Rutas
if [ -n "$ASSOC_RT_PUB_ID" ]; then
    delete_resource "Asociación de la Subred Pública" $ASSOC_RT_PUB_ID "aws ec2 disassociate-route-table --association-id $ASSOC_RT_PUB_ID --region $AWS_REGION"
fi

# Liberar Elastic IP
if [ -n "$EIP_ALLOC_ID" ]; then
    delete_resource "Elastic IP" $EIP_ALLOC_ID "aws ec2 release-address --allocation-id $EIP_ALLOC_ID --region $AWS_REGION"
fi

# Eliminar NAT Gateway
if [ -n "$NAT_GW_ID" ]; then
    delete_resource "NAT Gateway" $NAT_GW_ID "aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID --region $AWS_REGION"
    echo -e "${YELLOW}Esperando que el NAT Gateway se elimine completamente...${NC}"
    aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID --region $AWS_REGION
fi

# Eliminar Subredes
delete_resource "Subred Pública" $SUBNET_PUBLIC_ID "aws ec2 delete-subnet --subnet-id $SUBNET_PUBLIC_ID --region $AWS_REGION"
delete_resource "Subred Privada" $SUBNET_PRIVATE_ID "aws ec2 delete-subnet --subnet-id $SUBNET_PRIVATE_ID --region $AWS_REGION"

# Desasociar y eliminar Internet Gateway
if [ -n "$IGW_ID" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $AWS_REGION
    delete_resource "Internet Gateway" $IGW_ID "aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $AWS_REGION"
fi

# Eliminar Tabla de Rutas
delete_resource "Tabla de Rutas" $ROUTE_TABLE_ID "aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION"

# Eliminar VPC
delete_resource "VPC" $VPC_ID "aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION"

echo -e "${GREEN}Proceso de eliminación completado.${NC}"
