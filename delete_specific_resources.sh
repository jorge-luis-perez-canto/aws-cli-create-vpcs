#!/bin/bash
#**************************************************************************
# Script para Eliminar Recursos Específicos en AWS
#**************************************************************************

AWS_REGION="us-east-1"

# Identificadores de los recursos a eliminar
VPC_ID="vpc-05ceebdb10c58e6ff"
IGW_ID="igw-0a338840794efaf44"
ROUTE_TABLE_ID="rtb-01e3e5ee1d3eb2425"
MAIN_ROUTE_TABLE_ID="rtb-06b53b33d6cdeb32f"

# Colores para los mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color

# Función para eliminar un recurso específico con manejo de errores
function delete_resource() {
    local resource_type="$1"
    local resource_id="$2"
    local aws_command="$3"

    echo -e "${YELLOW}Eliminando ${resource_type} con ID ${resource_id}...${NC}"
    if eval $aws_command; then
        echo -e "${GREEN}${resource_type} con ID ${resource_id} eliminado correctamente.${NC}"
    else
        echo -e "${RED}Error al eliminar ${resource_type} con ID ${resource_id}.${NC}"
    fi
}

# Desasociar y eliminar Internet Gateway
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $AWS_REGION
delete_resource "Internet Gateway" $IGW_ID "aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $AWS_REGION"

# Eliminar Tabla de Rutas Principal
delete_resource "Tabla de Rutas Principal" $MAIN_ROUTE_TABLE_ID "aws ec2 delete-route-table --route-table-id $MAIN_ROUTE_TABLE_ID --region $AWS_REGION"

# Eliminar Tabla de Rutas
delete_resource "Tabla de Rutas" $ROUTE_TABLE_ID "aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION"

# Eliminar VPC
delete_resource "VPC" $VPC_ID "aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION"

echo -e "${GREEN}Todos los recursos especificados han sido eliminados.${NC}"
