#!/bin/bash
#******************************************************************************
#    Script de Shell para verificar la existencia de recursos de AWS y resumir
#******************************************************************************

AWS_REGION="us-east-1"
RESOURCE_FILE="aws_resources.txt"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color

# Arrays para almacenar el estado de los recursos
still_exists=()
not_exists=()

# Función para verificar cada recurso
function check_resource() {
    local RESOURCE_TYPE=$1
    local RESOURCE_ID=$2
    local AWS_COMMAND=$3

    if [ "$RESOURCE_ID" != "None" ] && [ -n "$RESOURCE_ID" ]; then
        echo -e "${YELLOW}Verificando ${RESOURCE_TYPE} con ID ${RESOURCE_ID}...${NC}"
        
        # Ejecutar el comando con redirección de stderr a /dev/null
        eval $AWS_COMMAND 2>/dev/null
        local status=$?
        
        if [ $status -eq 0 ]; then
            echo -e "${GREEN}${RESOURCE_TYPE} con ID ${RESOURCE_ID} todavía existe.${NC}"
            still_exists+=("${RESOURCE_TYPE} ID ${RESOURCE_ID}")
        else
            echo -e "${RED}${RESOURCE_TYPE} con ID ${RESOURCE_ID} no existe o no se pudo verificar.${NC}"
            not_exists+=("${RESOURCE_TYPE} ID ${RESOURCE_ID}")
        fi
    else
        echo -e "${RED}No hay ID registrado para ${RESOURCE_TYPE}.${NC}"
    fi
    echo ""
}

# Leer y verificar cada recurso del archivo
while IFS=": " read -r key value; do
    case "$key" in
        VPC_ID) check_resource "VPC" "$value" "aws ec2 describe-vpcs --vpc-ids $value --region $AWS_REGION" ;;
        SUBNET_PUBLIC_ID) check_resource "Subred Pública" "$value" "aws ec2 describe-subnets --subnet-ids $value --region $AWS_REGION" ;;
        SUBNET_PRIVATE_ID) check_resource "Subred Privada" "$value" "aws ec2 describe-subnets --subnet-ids $value --region $AWS_REGION" ;;
        IGW_ID) check_resource "Internet Gateway" "$value" "aws ec2 describe-internet-gateways --internet-gateway-ids $value --region $AWS_REGION" ;;
        ASSOC_IGW_ID) check_resource "Asociación de IGW" "$value" "aws ec2 describe-internet-gateways --filters Name=attachment.internet-gateway-id,Values=$value --region $AWS_REGION" ;;
        ROUTE_TABLE_ID) check_resource "Tabla de Rutas" "$value" "aws ec2 describe-route-tables --route-table-ids $value --region $AWS_REGION" ;;
        ASSOC_RT_PUB_ID) check_resource "Asociación de la Tabla de Rutas" "$value" "aws ec2 describe-route-tables --route-table-ids $value --region $AWS_REGION" ;;
        EIP_ALLOC_ID) check_resource "Elastic IP" "$value" "aws ec2 describe-addresses --allocation-ids $value --region $AWS_REGION" ;;
        NAT_GW_ID) check_resource "NAT Gateway" "$value" "aws ec2 describe-nat-gateways --nat-gateway-ids $value --region $AWS_REGION" ;;
        MAIN_ROUTE_TABLE_ID) check_resource "Tabla de Rutas Principal" "$value" "aws ec2 describe-route-tables --route-table-ids $value --region $AWS_REGION" ;;
    esac
done < "$RESOURCE_FILE"

# Mostrar resumen al final
echo -e "${GREEN}Recursos que aún existen:${NC}"
for item in "${still_exists[@]}"; do
    echo -e "${GREEN}$item${NC}"
done

echo -e "${RED}Recursos que no existen o no se pudieron verificar:${NC}"
for item in "${not_exists[@]}"; do
    echo -e "${RED}$item${NC}"
done
