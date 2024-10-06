#!/bin/bash
#******************************************************************************
#    Script Mejorado para la Eliminación Segura de una VPC en AWS
#******************************************************************************
#
# SINOPSIS
#    Automatiza la eliminación de una VPC personalizada y sus recursos asociados.
#
# DESCRIPCIÓN
#    Este script de shell utiliza la Interfaz de Línea de Comandos de AWS (AWS CLI)
#    para eliminar automáticamente una VPC personalizada y todos sus recursos, 
#    manejando de forma segura dependencias y errores.
#
#******************************************************************************
#
# NOTAS
#   VERSIÓN:   1.0.0
#   ÚLTIMA EDICIÓN:  05/10/2024
#   AUTORES:
#       - Jorge Luis Pérez Canto (george.jlpc@gmail.com)
#
#******************************************************************************

# Configuraciones iniciales
AWS_REGION="us-east-1"
RESOURCE_FILE="aws_resources.txt"

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color

#******************************************************************************
# Funciones para el manejo de recursos
#******************************************************************************

# Función para leer ID de recursos desde el archivo
function read_resource_id() {
    grep "$1" $RESOURCE_FILE | cut -d ':' -f2 | xargs
}

# Función para eliminar un recurso con manejo de errores
function delete_resource() {
    local RESOURCE_TYPE=$1
    local RESOURCE_ID=$2
    local AWS_COMMAND=$3

    echo -e "${YELLOW}Intentando eliminar ${RESOURCE_TYPE} con ID ${RESOURCE_ID}...${NC}"
    if eval $AWS_COMMAND; then
        echo -e "${GREEN}${RESOURCE_TYPE} con ID ${RESOURCE_ID} ha sido eliminado correctamente.${NC}"
    else
        echo -e "${RED}Error al eliminar ${RESOURCE_TYPE} con ID ${RESOURCE_ID}.${NC}"
    fi
}

# Leer los IDs de los recursos desde el archivo
VPC_ID=$(read_resource_id "VPC_ID")
SUBNET_PUBLIC_ID=$(read_resource_id "SUBNET_PUBLIC_ID")
SUBNET_PRIVATE_ID=$(read_resource_id "SUBNET_PRIVATE_ID")
IGW_ID=$(read_resource_id "IGW_ID")
ROUTE_TABLE_ID=$(read_resource_id "ROUTE_TABLE_ID")
ASSOC_RT_PUB_ID=$(read_resource_id "ASSOC_RT_PUB_ID")
EIP_ALLOC_ID=$(read_resource_id "EIP_ALLOC_ID")
NAT_GW_ID=$(read_resource_id "NAT_GW_ID")
MAIN_ROUTE_TABLE_ID=$(read_resource_id "MAIN_ROUTE_TABLE_ID")

#******************************************************************************
# Desasociar y eliminar recursos en orden seguro
#******************************************************************************

# Desasociar la Subred Pública de la Tabla de Rutas
if [ -n "$ASSOC_RT_PUB_ID" ]; then
    delete_resource "Asociación de Tabla de Rutas" $ASSOC_RT_PUB_ID "aws ec2 disassociate-route-table --association-id $ASSOC_RT_PUB_ID --region $AWS_REGION"
fi

# Eliminar NAT Gateway
if [ -n "$NAT_GW_ID" ]; then
    delete_resource "NAT Gateway" $NAT_GW_ID "aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID --region $AWS_REGION"
    echo -e "${YELLOW}Esperando a que el NAT Gateway sea completamente eliminado...${NC}"
    aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID --region $AWS_REGION
    echo -e "${GREEN}NAT Gateway ha sido eliminado.${NC}"
fi

# Liberar Elastic IP
if [ -n "$EIP_ALLOC_ID" ]; then
    delete_resource "Elastic IP" $EIP_ALLOC_ID "aws ec2 release-address --allocation-id $EIP_ALLOC_ID --region $AWS_REGION"
fi

# Eliminar subredes
if [ -n "$SUBNET_PUBLIC_ID" ]; then
    delete_resource "Subred Pública" $SUBNET_PUBLIC_ID "aws ec2 delete-subnet --subnet-id $SUBNET_PUBLIC_ID --region $AWS_REGION"
fi

if [ -n "$SUBNET_PRIVATE_ID" ]; then
    delete_resource "Subred Privada" $SUBNET_PRIVATE_ID "aws ec2 delete-subnet --subnet-id $SUBNET_PRIVATE_ID --region $AWS_REGION"
fi

# Desasociar y eliminar Internet Gateway
if [ -n "$IGW_ID" ]; then
    delete_resource "Internet Gateway" $IGW_ID "aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $AWS_REGION && aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $AWS_REGION"
fi

# Eliminar rutas de la tabla de rutas principal antes de eliminarla
if [ -n "$MAIN_ROUTE_TABLE_ID" ]; then
    echo -e "${YELLOW}Eliminando rutas no locales de la tabla de rutas principal...${NC}"
    aws ec2 describe-route-tables --route-table-ids $MAIN_ROUTE_TABLE_ID --region $AWS_REGION --query 'RouteTables[*].Routes' --output text | while read route; do
        destination=$(echo $route | awk '{print $1}')
        if [ "$destination" != "local" ]; then
            delete_resource "Ruta" $destination "aws ec2 delete-route --route-table-id $MAIN_ROUTE_TABLE_ID --destination-cidr-block $destination --region $AWS_REGION"
        fi
    done
    delete_resource "Tabla de Rutas Principal" $MAIN_ROUTE_TABLE_ID "aws ec2 delete-route-table --route-table-id $MAIN_ROUTE_TABLE_ID --region $AWS_REGION"
fi

# Eliminar la tabla de rutas secundaria
if [ -n "$ROUTE_TABLE_ID" ]; then
    delete_resource "Tabla de Rutas" $ROUTE_TABLE_ID "aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION"
fi

# Eliminar VPC
if [ -n "$VPC_ID" ]; then
    delete_resource "VPC" $VPC_ID "aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION"
fi

echo -e "${GREEN}Todos los recursos han sido eliminados.${NC}"
