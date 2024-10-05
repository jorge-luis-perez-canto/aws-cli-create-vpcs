#!/bin/bash
#******************************************************************************
#    Script de Shell para la Creación de una VPC en AWS
#******************************************************************************
#
# SINOPSIS
#    Automatiza la creación de una VPC personalizada con IPv4, que incluye tanto
#    una subred pública como una subred privada, y una puerta de enlace NAT.
#
# DESCRIPCIÓN
#    Este script de shell utiliza la Interfaz de Línea de Comandos de AWS (AWS CLI)
#    para crear automáticamente una VPC personalizada. El script asume que la AWS CLI
#    está instalada y configurada con las credenciales de seguridad necesarias.
#
#******************************************************************************
#
# NOTAS
#   VERSIÓN:   0.2.0
#   ÚLTIMA EDICIÓN:  05/10/2024
#   AUTORES:
#       - Joe Arauzo (joe@arauzo.net)
#       - Jorge Luis Pérez Canto (george.jlpc@gmail.com)
#
#******************************************************************************
#   MODIFICA LOS AJUSTES A CONTINUACIÓN
#******************************************************************************

AWS_REGION="us-east-1"
VPC_NAME="Mi VPC Jorge Pérez"
VPC_CIDR="10.0.0.0/16"
SUBNET_PUBLIC_CIDR="10.0.1.0/24"
SUBNET_PUBLIC_AZ="us-east-1a"
SUBNET_PUBLIC_NAME="10.0.1.0 - us-east-1a"
SUBNET_PRIVATE_CIDR="10.0.2.0/24"
SUBNET_PRIVATE_AZ="us-east-1b"
SUBNET_PRIVATE_NAME="10.0.2.0 - us-east-1b"
CHECK_FREQUENCY=5
RESOURCE_FILE="aws_resources.txt"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color

#******************************************************************************
#   NO MODIFIQUES EL CÓDIGO A CONTINUACIÓN
#******************************************************************************

# Crear archivo de recursos
echo -e "${YELLOW}Inicializando registro de recursos...${NC}"
echo "" > $RESOURCE_FILE

# Función para almacenar ID de recurso
function save_resource_id() {
    echo "$1: $2" >> $RESOURCE_FILE
}

# Crear la VPC
echo -e "${YELLOW}Creando VPC en la región preferida...${NC}"
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --query 'Vpc.{VpcId:VpcId}' \
  --output text \
  --region $AWS_REGION)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}VPC ID '$VPC_ID' CREADA en la región '$AWS_REGION'.${NC}"
    save_resource_id "VPC_ID" $VPC_ID
else
    echo -e "${RED}Error al crear VPC.${NC}"
    exit 1
fi

# Añadir etiqueta de nombre a la VPC
aws ec2 create-tags \
  --resources $VPC_ID \
  --tags "Key=Name,Value=$VPC_NAME" \
  --region $AWS_REGION
echo -e "${GREEN}VPC ID '$VPC_ID' NOMBRADA como '$VPC_NAME'.${NC}"

# Crear Subred Pública
echo -e "${YELLOW}Creando Subred Pública...${NC}"
SUBNET_PUBLIC_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_PUBLIC_CIDR \
  --availability-zone $SUBNET_PUBLIC_AZ \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text \
  --region $AWS_REGION)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Subnet ID '$SUBNET_PUBLIC_ID' CREADA en la zona de disponibilidad '$SUBNET_PUBLIC_AZ'.${NC}"
    save_resource_id "SUBNET_PUBLIC_ID" $SUBNET_PUBLIC_ID
else
    echo -e "${RED}Error al crear la Subred Pública.${NC}"
    exit 1
fi

# Añadir etiqueta de nombre a la Subred Pública
aws ec2 create-tags \
  --resources $SUBNET_PUBLIC_ID \
  --tags "Key=Name,Value=$SUBNET_PUBLIC_NAME" \
  --region $AWS_REGION
echo -e "${GREEN}Subnet ID '$SUBNET_PUBLIC_ID' NOMBRADA como '$SUBNET_PUBLIC_NAME'.${NC}"

# Crear Subred Privada
echo -e "${YELLOW}Creando Subred Privada...${NC}"
SUBNET_PRIVATE_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_PRIVATE_CIDR \
  --availability-zone $SUBNET_PRIVATE_AZ \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text \
  --region $AWS_REGION)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Subnet ID '$SUBNET_PRIVATE_ID' CREADA en la zona de disponibilidad '$SUBNET_PRIVATE_AZ'.${NC}"
    save_resource_id "SUBNET_PRIVATE_ID" $SUBNET_PRIVATE_ID
else
    echo -e "${RED}Error al crear la Subnet Privada.${NC}"
    exit 1
fi

# Añadir etiqueta de nombre a la Subred Privada
aws ec2 create-tags \
  --resources $SUBNET_PRIVATE_ID \
  --tags "Key=Name,Value=$SUBNET_PRIVATE_NAME" \
  --region $AWS_REGION
echo -e "${GREEN}Subnet ID '$SUBNET_PRIVATE_ID' NOMBRADA como '$SUBNET_PRIVATE_NAME'.${NC}"

# Crear la puerta de enlace de Internet
echo -e "${YELLOW}Creando Puerta de Enlace de Internet...${NC}"
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' \
  --output text \
  --region $AWS_REGION)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Puerta de Enlace de Internet ID '$IGW_ID' CREADA.${NC}"
    save_resource_id "IGW_ID" $IGW_ID
else
    echo -e "${RED}Error al crear la Puerta de Enlace de Internet.${NC}"
    exit 1
fi

# Asociar la puerta de enlace de Internet a la VPC
ASSOC_IGW_ID=$(aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID \
  --query 'Attachment.{AttachmentId:InternetGatewayId}' \
  --output text \
  --region $AWS_REGION)
echo -e "${GREEN}Puerta de Enlace de Internet ID '$IGW_ID' ASOCIADA a la VPC ID '$VPC_ID'.${NC}"
save_resource_id "ASSOC_IGW_ID" $ASSOC_IGW_ID

# Crear Tabla de Rutas
echo -e "${YELLOW}Creando Tabla de Rutas...${NC}"
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.{RouteTableId:RouteTableId}' \
  --output text \
  --region $AWS_REGION)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Tabla de Rutas ID '$ROUTE_TABLE_ID' CREADA.${NC}"
    save_resource_id "ROUTE_TABLE_ID" $ROUTE_TABLE_ID
else
    echo -e "${RED}Error al crear la Tabla de Rutas.${NC}"
    exit 1
fi

# Crear ruta hacia la Puerta de Enlace de Internet
RESULT=$(aws ec2 create-route \
  --route-table-id $ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $AWS_REGION)
echo -e "${GREEN}Ruta hacia '0.0.0.0/0' a través de la Puerta de Enlace de Internet ID '$IGW_ID' AÑADIDA a la Tabla de Rutas ID '$ROUTE_TABLE_ID'.${NC}"

# Asociar Subred Pública con la Tabla de Rutas
ASSOC_RT_PUB_ID=$(aws ec2 associate-route-table \
  --subnet-id $SUBNET_PUBLIC_ID \
  --route-table-id $ROUTE_TABLE_ID \
  --query 'AssociationId' \
  --output text \
  --region $AWS_REGION)
echo -e "${GREEN}Subnet Pública ID '$SUBNET_PUBLIC_ID' ASOCIADA con la Tabla de Rutas ID '$ROUTE_TABLE_ID'.${NC}"
save_resource_id "ASSOC_RT_PUB_ID" $ASSOC_RT_PUB_ID

# Habilitar asignación automática de IP pública en la Subnet Pública
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_PUBLIC_ID \
  --map-public-ip-on-launch \
  --region $AWS_REGION
echo -e "${GREEN}Asignación automática de IP pública HABILITADA en la Subnet Pública ID '$SUBNET_PUBLIC_ID'.${NC}"

# Asignar dirección IP elástica para la Puerta de Enlace NAT
echo -e "${YELLOW}Creando Puerta de Enlace NAT...${NC}"
EIP_ALLOC_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --query '{AllocationId:AllocationId}' \
  --output text \
  --region $AWS_REGION)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Dirección IP elástica ID '$EIP_ALLOC_ID' ASIGNADA.${NC}"
    save_resource_id "EIP_ALLOC_ID" $EIP_ALLOC_ID
else
    echo -e "${RED}Error al asignar la dirección IP elástica.${NC}"
    exit 1
fi

# Crear Puerta de Enlace NAT
NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $SUBNET_PUBLIC_ID \
  --allocation-id $EIP_ALLOC_ID \
  --query 'NatGateway.{NatGatewayId:NatGatewayId}' \
  --output text \
  --region $AWS_REGION)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Puerta de Enlace NAT ID '$NAT_GW_ID' CREADA y esperando a que esté disponible.${NC}"
    save_resource_id "NAT_GW_ID" $NAT_GW_ID
else
    echo -e "${RED}Error al crear la Puerta de Enlace NAT.${NC}"
    exit 1
fi

# Esperar a que la Puerta de Enlace NAT esté disponible
echo -e "${YELLOW}Por favor, sea paciente mientras la Puerta de Enlace NAT se inicializa...${NC}"
SECONDS=0
LAST_CHECK=0
STATE='PENDING'
until [[ $STATE == 'AVAILABLE' ]]; do
    INTERVAL=$SECONDS-$LAST_CHECK
    if [[ $INTERVAL -ge $CHECK_FREQUENCY ]]; then
        STATE=$(aws ec2 describe-nat-gateways \
          --nat-gateway-ids $NAT_GW_ID \
          --query 'NatGateways[*].{State:State}' \
          --output text \
          --region $AWS_REGION)
        STATE=$(echo $STATE | tr '[:lower:]' '[:upper:]')
        LAST_CHECK=$SECONDS
    fi
    printf "    ESTADO: %s  -  %02dh:%02dm:%02ds transcurridos...\r" $STATE $(($SECONDS/3600)) $(($SECONDS%3600/60)) $(($SECONDS%60))
    sleep 1
done
echo -e "\n    ${GREEN}Puerta de Enlace NAT ID '$NAT_GW_ID' está ahora DISPONIBLE.${NC}"

# Crear ruta hacia la Puerta de Enlace NAT
MAIN_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" \
  --query 'RouteTables[*].{RouteTableId:RouteTableId}' \
  --output text \
  --region $AWS_REGION)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}La Tabla de Rutas Principal es '$MAIN_ROUTE_TABLE_ID'.${NC}"
    save_resource_id "MAIN_ROUTE_TABLE_ID" $MAIN_ROUTE_TABLE_ID
else
    echo -e "${RED}Error al obtener la Tabla de Rutas Principal.${NC}"
    exit 1
fi

RESULT=$(aws ec2 create-route \
  --route-table-id $MAIN_ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $NAT_GW_ID \
  --region $AWS_REGION)
echo -e "${GREEN}Ruta hacia '0.0.0.0/0' a través de la Puerta de Enlace NAT ID '$NAT_GW_ID' AÑADIDA a la Tabla de Rutas ID '$MAIN_ROUTE_TABLE_ID'.${NC}"
echo -e "${GREEN}COMPLETADO${NC}"
