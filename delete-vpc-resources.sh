#!/bin/bash

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Sin color

# Variables con los IDs obtenidos al crear los recursos
AWS_REGION="us-east-1"
VPC_ID="vpc-0c4e519ed6ec21c8e"
SUBNET_PUBLIC_ID="subnet-027bd5cf12a245af5"
SUBNET_PRIVATE_ID="subnet-0a6c7f3e46826835b"
IGW_ID="igw-087510ed728b5d3cd"
NAT_GW_ID="nat-00956314797e39cef"
EIP_ALLOC_ID="eipalloc-0a629eadbdeafde5f"
ROUTE_TABLE_ID="rtb-012ffa473aa1faf69"
MAIN_ROUTE_TABLE_ID="rtb-0d8d3681eecc4455a"

# Separador
function separator() {
    echo -e "${CYAN}\n----------------------------------------\n${NC}"
}

# Mostrar recursos existentes de un tipo
function list_resources() {
    RESOURCE_TYPE=$1
    QUERY=$2
    DESCRIPTION=$3

    echo -e "${YELLOW}Listando $DESCRIPTION en la región '${AWS_REGION}':${NC}"
    aws ec2 $RESOURCE_TYPE --query "$QUERY" --output table --region $AWS_REGION
}

# Verificación de existencia de recursos y listado de recursos si no se encuentra
function check_resource_exists() {
    RESOURCE_TYPE=$1
    RESOURCE_ID=$2
    COMMAND=$3
    LIST_COMMAND=$4

    echo -e "${YELLOW}Verificando si $RESOURCE_TYPE '$RESOURCE_ID' existe...${NC}"
    
    if $COMMAND > /dev/null 2>&1; then
        echo -e "${GREEN}$RESOURCE_TYPE '$RESOURCE_ID' encontrado.${NC}"
    else
        echo -e "${RED}$RESOURCE_TYPE '$RESOURCE_ID' NO encontrado.${NC}"
        echo -e "${YELLOW}Listando los $RESOURCE_TYPE disponibles:${NC}"
        $LIST_COMMAND
        exit 1
    fi
}

# Eliminar NAT Gateway
function delete_nat_gateway() {
    separator
    echo -e "${YELLOW}Eliminando Puerta de Enlace NAT...${NC}"
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID --region $AWS_REGION > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Puerta de Enlace NAT '$NAT_GW_ID' eliminada correctamente.${NC}"
    else
        echo -e "${RED}Error al eliminar la Puerta de Enlace NAT. Verificando las NAT Gateways existentes...${NC}"
        list_resources "describe-nat-gateways" "NatGateways[*].{ID:NatGatewayId,Etiqueta:Tags[0].Value}" "NAT Gateways"
    fi
}

# Liberar IP elástica
function release_elastic_ip() {
    separator
    echo -e "${YELLOW}Liberando Dirección IP Elástica...${NC}"
    aws ec2 release-address --allocation-id $EIP_ALLOC_ID --region $AWS_REGION > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Dirección IP Elástica '$EIP_ALLOC_ID' liberada correctamente.${NC}"
    else
        echo -e "${RED}Error al liberar la Dirección IP Elástica. Verificando las IPs elásticas existentes...${NC}"
        list_resources "describe-addresses" "Addresses[*].{ID:AllocationId,Etiqueta:Tags[0].Value}" "IPs Elásticas"
    fi
}

# Eliminar rutas
function delete_route() {
    separator
    echo -e "${YELLOW}Eliminando rutas a NAT Gateway...${NC}"
    aws ec2 delete-route --route-table-id $MAIN_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --region $AWS_REGION > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Ruta a NAT Gateway eliminada correctamente.${NC}"
    else
        echo -e "${RED}No se encontró la ruta o error al eliminarla. Verificando las rutas existentes...${NC}"
        list_resources "describe-route-tables" "RouteTables[*].{ID:RouteTableId,Route:Routes[*].DestinationCidrBlock}" "Tablas de Rutas"
    fi
}

# Desasociar tabla de rutas
function disassociate_route_table() {
    separator
    echo -e "${YELLOW}Desasociando Tabla de Rutas...${NC}"
    ASSOCIATION_ID=$(aws ec2 describe-route-tables --filters "Name=route-table-id,Values=$ROUTE_TABLE_ID" --query "RouteTables[*].Associations[*].RouteTableAssociationId" --output text --region $AWS_REGION)
    
    if [ ! -z "$ASSOCIATION_ID" ]; then
        aws ec2 disassociate-route-table --association-id $ASSOCIATION_ID --region $AWS_REGION > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Tabla de Rutas desasociada correctamente.${NC}"
        else
            echo -e "${RED}Error al desasociar la Tabla de Rutas. Verificando asociaciones de tablas de rutas existentes...${NC}"
            list_resources "describe-route-tables" "RouteTables[*].{ID:RouteTableId,Asociaciones:Associations[*].RouteTableAssociationId}" "Asociaciones de Tablas de Rutas"
        fi
    else
        echo -e "${RED}No se encontró una asociación de tabla de rutas. Verificando asociaciones de tablas de rutas existentes...${NC}"
        list_resources "describe-route-tables" "RouteTables[*].{ID:RouteTableId,Asociaciones:Associations[*].RouteTableAssociationId}" "Asociaciones de Tablas de Rutas"
    fi
}

# Eliminar tabla de rutas
function delete_route_table() {
    separator
    echo -e "${YELLOW}Eliminando Tabla de Rutas...${NC}"
    aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Tabla de Rutas '$ROUTE_TABLE_ID' eliminada correctamente.${NC}"
    else
        echo -e "${RED}Error al eliminar la Tabla de Rutas. Verificando tablas de rutas existentes...${NC}"
        list_resources "describe-route-tables" "RouteTables[*].{ID:RouteTableId,Etiqueta:Tags[0].Value}" "Tablas de Rutas"
    fi
}

# Desasociar y eliminar Puerta de Enlace de Internet
function delete_internet_gateway() {
    separator
    echo -e "${YELLOW}Desasociando y eliminando Puerta de Enlace de Internet...${NC}"
    
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $AWS_REGION > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Puerta de Enlace de Internet desasociada correctamente.${NC}"
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $AWS_REGION > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Puerta de Enlace de Internet eliminada correctamente.${NC}"
        else
            echo -e "${RED}Error al eliminar la Puerta de Enlace de Internet. Verificando puertas de enlace de internet existentes...${NC}"
            list_resources "describe-internet-gateways" "InternetGateways[*].{ID:InternetGatewayId,Etiqueta:Tags[0].Value}" "Puertas de Enlace de Internet"
        fi
    else
        echo -e "${RED}Error al desasociar la Puerta de Enlace de Internet. Verificando puertas de enlace de internet existentes...${NC}"
        list_resources "describe-internet-gateways" "InternetGateways[*].{ID:InternetGatewayId,Etiqueta:Tags[0].Value}" "Puertas de Enlace de Internet"
    fi
}

# Eliminar Subredes
function delete_subnets() {
    separator
    echo -e "${YELLOW}Eliminando Subredes...${NC}"
    
    aws ec2 delete-subnet --subnet-id $SUBNET_PUBLIC_ID --region $AWS_REGION > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Subred Pública '$SUBNET_PUBLIC_ID' eliminada correctamente.${NC}"
    else
        echo -e "${RED}Error al eliminar la Subred Pública. Verificando subredes existentes...${NC}"
        list_resources "describe-subnets" "Subnets[*].{ID:SubnetId,Etiqueta:Tags[0].Value}" "Subredes"
    fi

    aws ec2 delete-subnet --subnet-id $SUBNET_PRIVATE_ID --region $AWS_REGION > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Subred Privada '$SUBNET_PRIVATE_ID' eliminada correctamente.${NC}"
    else
        echo -e "${RED}Error al eliminar la Subred Privada. Verificando subredes existentes...${NC}"
        list_resources "describe-subnets" "Subnets[*].{ID:SubnetId,Etiqueta:Tags[0].Value}" "Subredes"
    fi
}

# Eliminar VPC
function delete_vpc() {
    separator
    echo -e "${YELLOW}Eliminando VPC...${NC}"
    
    aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}VPC '$VPC_ID' eliminada correctamente.${NC}"
    else
        echo -e "${RED}Error al eliminar la VPC. Verificando VPCs existentes...${NC}"
        list_resources "describe-vpcs" "Vpcs[*].{ID:VpcId,Etiqueta:Tags[0].Value}" "VPCs"
    fi
}

# Comienza la ejecución del script

# Verificaciones
separator
echo -e "${CYAN}Iniciando el proceso de eliminación de recursos de la VPC...${NC}"
check_resource_exists "VPC" $VPC_ID "aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $AWS_REGION" "aws ec2 describe-vpcs --query 'Vpcs[*].VpcId' --region $AWS_REGION"
check_resource_exists "Puerta de Enlace NAT" $NAT_GW_ID "aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_ID --region $AWS_REGION" "aws ec2 describe-nat-gateways --query 'NatGateways[*].NatGatewayId' --region $AWS_REGION"
check_resource_exists "Puerta de Enlace de Internet" $IGW_ID "aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID --region $AWS_REGION" "aws ec2 describe-internet-gateways --query 'InternetGateways[*].InternetGatewayId' --region $AWS_REGION"

# Eliminar recursos en orden
delete_nat_gateway
release_elastic_ip
delete_route
disassociate_route_table
delete_route_table
delete_internet_gateway
delete_subnets
delete_vpc

separator
echo -e "${CYAN}Todos los recursos han sido eliminados.${NC}"
