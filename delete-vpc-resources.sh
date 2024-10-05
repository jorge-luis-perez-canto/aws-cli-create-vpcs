#!/bin/bash
#******************************************************************************
#    Script de Shell para la Eliminación de una VPC en AWS
#******************************************************************************
#
# SINOPSIS
#    Automatiza la eliminación de una VPC personalizada y sus recursos asociados.
#
# DESCRIPCIÓN
#    Este script de shell utiliza la Interfaz de Línea de Comandos de AWS (AWS CLI)
#    para eliminar automáticamente una VPC personalizada y todos sus recursos.
#
#******************************************************************************
#
# NOTAS
#   VERSIÓN:   0.1.0
#   ÚLTIMA EDICIÓN:  05/10/2024
#   AUTORES:
#       - Jorge Luis Pérez Canto (george.jlpc@gmail.com)
#
#******************************************************************************
#
# Configuraciones iniciales
#******************************************************************************

AWS_REGION="us-east-1"
RESOURCE_FILE="aws_resources.txt"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color

#******************************************************************************
#   Código del script
#******************************************************************************

# Función para leer ID de recursos del archivo
function read_resource_id() {
    grep "$1" $RESOURCE_FILE | cut -d ':' -f2 | xargs
}

# Leer los IDs desde el archivo
VPC_ID=$(read_resource_id "VPC_ID")
SUBNET_PUBLIC_ID=$(read_resource_id "SUBNET_PUBLIC_ID")
SUBNET_PRIVATE_ID=$(read_resource_id "SUBNET_PRIVATE_ID")
IGW_ID=$(read_resource_id "IGW_ID")
ROUTE_TABLE_ID=$(read_resource_id "ROUTE_TABLE_ID")
ASSOC_RT_PUB_ID=$(read_resource_id "ASSOC_RT_PUB_ID")
EIP_ALLOC_ID=$(read_resource_id "EIP_ALLOC_ID")
NAT_GW_ID=$(read_resource_id "NAT_GW_ID")
MAIN_ROUTE_TABLE_ID=$(read_resource_id "MAIN_ROUTE_TABLE_ID")

# Función para eliminar un recurso con manejo de excepciones
function delete_resource() {
    local RESOURCE_TYPE=$1
    local RESOURCE_ID=$2
    local AWS_COMMAND=$3

    echo -e "${YELLOW}Intentando eliminar ${RESOURCE_TYPE} con ID ${RESOURCE_ID}...${NC}"
    if ! eval $AWS_COMMAND; then
        echo -e "${RED}No se pudo eliminar ${RESOURCE_TYPE} con ID ${RESOURCE_ID}. Verificando...${NC}"
        aws ec2 "describe-${RESOURCE_TYPE}s" --region $AWS_REGION
    else
        echo -e "${GREEN}${RESOURCE_TYPE} con ID ${RESOURCE_ID} ha sido eliminado correctamente.${NC}"
    fi
}

# Desasociar y eliminar recursos en orden específico

# Desasociar la Subred Pública de la Tabla de Rutas
if [ -n "$ASSOC_RT_PUB_ID" ]; then
    delete_resource "route-table-association" $ASSOC_RT_PUB_ID "aws ec2 disassociate-route-table --association-id $ASSOC_RT_PUB_ID --region $AWS_REGION"
fi

# Eliminar NAT Gateway
if [ -n "$NAT_GW_ID" ]; then
    delete_resource "nat-gateway" $NAT_GW_ID "aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID --region $AWS_REGION"
    # Esperar a que el estado del NAT Gateway sea 'deleted'
    echo -e "${YELLOW}Esperando a que el NAT Gateway sea eliminado completamente...${NC}"
    aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID --region $AWS_REGION
    echo -e "${GREEN}NAT Gateway ha sido eliminado completamente.${NC}"
fi

# Liberar Elastic IP
if [ -n "$EIP_ALLOC_ID" ]; then
    delete_resource "eip" $EIP_ALLOC_ID "aws ec2 release-address --allocation-id $EIP_ALLOC_ID --region $AWS_REGION"
fi

# Eliminar subredes
delete_resource "subnet" $SUBNET_PUBLIC_ID "aws ec2 delete-subnet --subnet-id $SUBNET_PUBLIC_ID --region $AWS_REGION"
delete_resource "subnet" $SUBNET_PRIVATE_ID "aws ec2 delete-subnet --subnet-id $SUBNET_PRIVATE_ID --region $AWS_REGION"

# Desasociar y eliminar Internet Gateway
if [ -n "$IGW_ID" ]; then
    delete_resource "internet-gateway" $IGW_ID "aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $AWS_REGION && aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $AWS_REGION"
fi

# Eliminar Tabla de Rutas
if [ -n "$ROUTE_TABLE_ID" ]; then
    delete_resource "route-table" $ROUTE_TABLE_ID "aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION"
fi

# Eliminar VPC
if [ -n "$VPC_ID" ]; then
    delete_resource "vpc" $VPC_ID "aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION"
fi

echo -e "${GREEN}Todos los recursos han sido eliminados.${NC}"
