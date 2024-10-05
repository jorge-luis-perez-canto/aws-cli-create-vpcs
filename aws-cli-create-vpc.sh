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
#==============================================================================
#
# NOTAS
#   VERSIÓN:   0.2.0
#   ÚLTIMA EDICIÓN:  05/10/2024
#   AUTORES:
#       - Joe Arauzo (joe@arauzo.net)
#       - Jorge Luis Pérez Canto (george.jlpc@gmail.com)
#
#   REVISIONES:
#       0.2.0  05/10/2024 - mejoras y modificaciones por Jorge Pérez
#       0.1.0  18/03/2017 - primera versión por Joe Arauzo
#       0.0.1  25/02/2017 - trabajo en progreso por Joe Arauzo
#
#==============================================================================
#   MODIFICA LOS AJUSTES A CONTINUACIÓN
#==============================================================================

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
#
#==============================================================================
#   NO MODIFIQUES EL CÓDIGO A CONTINUACIÓN
#==============================================================================
#
# Crear la VPC
echo "Creando VPC en la región preferida..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --query 'Vpc.{VpcId:VpcId}' \
  --output text \
  --region $AWS_REGION)
echo "  VPC ID '$VPC_ID' CREADA en la región '$AWS_REGION'."

# Añadir etiqueta de nombre a la VPC
aws ec2 create-tags \
  --resources $VPC_ID \
  --tags "Key=Name,Value=$VPC_NAME" \
  --region $AWS_REGION
echo "  VPC ID '$VPC_ID' NOMBRADA como '$VPC_NAME'."

# Crear Subred Pública
echo "Creando Subred Pública..."
SUBNET_PUBLIC_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_PUBLIC_CIDR \
  --availability-zone $SUBNET_PUBLIC_AZ \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text \
  --region $AWS_REGION)
echo "  Subnet ID '$SUBNET_PUBLIC_ID' CREADA en la zona de disponibilidad" \
  "'$SUBNET_PUBLIC_AZ'."

# Añadir etiqueta de nombre a la Subred Pública
aws ec2 create-tags \
  --resources $SUBNET_PUBLIC_ID \
  --tags "Key=Name,Value=$SUBNET_PUBLIC_NAME" \
  --region $AWS_REGION
echo "  Subnet ID '$SUBNET_PUBLIC_ID' NOMBRADA como '$SUBNET_PUBLIC_NAME'."

# Crear Subred Privada
echo "Creando Subred Privada..."
SUBNET_PRIVATE_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_PRIVATE_CIDR \
  --availability-zone $SUBNET_PRIVATE_AZ \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text \
  --region $AWS_REGION)
echo "  Subnet ID '$SUBNET_PRIVATE_ID' CREADA en la zona de disponibilidad" \
  "'$SUBNET_PRIVATE_AZ'."

# Añadir etiqueta de nombre a la Subred Privada
aws ec2 create-tags \
  --resources $SUBNET_PRIVATE_ID \
  --tags "Key=Name,Value=$SUBNET_PRIVATE_NAME" \
  --region $AWS_REGION
echo "  Subnet ID '$SUBNET_PRIVATE_ID' NOMBRADA como '$SUBNET_PRIVATE_NAME'."

# Crear la puerta de enlace de Internet
echo "Creando Puerta de Enlace de Internet..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' \
  --output text \
  --region $AWS_REGION)
echo "  Puerta de Enlace de Internet ID '$IGW_ID' CREADA."

# Asociar la puerta de enlace de Internet a tu VPC
aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID \
  --region $AWS_REGION
echo "  Puerta de Enlace de Internet ID '$IGW_ID' ASOCIADA a la VPC ID '$VPC_ID'."

# Crear Tabla de Rutas
echo "Creando Tabla de Rutas..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.{RouteTableId:RouteTableId}' \
  --output text \
  --region $AWS_REGION)
echo "  Tabla de Rutas ID '$ROUTE_TABLE_ID' CREADA."

# Crear ruta hacia la Puerta de Enlace de Internet
RESULT=$(aws ec2 create-route \
  --route-table-id $ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $AWS_REGION)
echo "  Ruta hacia '0.0.0.0/0' a través de la Puerta de Enlace de Internet ID '$IGW_ID' AÑADIDA a la Tabla de Rutas ID '$ROUTE_TABLE_ID'."

# Asociar Subred Pública con la Tabla de Rutas
RESULT=$(aws ec2 associate-route-table  \
  --subnet-id $SUBNET_PUBLIC_ID \
  --route-table-id $ROUTE_TABLE_ID \
  --region $AWS_REGION)
echo "  Subnet Pública ID '$SUBNET_PUBLIC_ID' ASOCIADA con la Tabla de Rutas ID '$ROUTE_TABLE_ID'."

# Habilitar asignación automática de IP pública en la Subnet Pública
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_PUBLIC_ID \
  --map-public-ip-on-launch \
  --region $AWS_REGION
echo "  Asignación automática de IP pública HABILITADA en la Subnet Pública ID '$SUBNET_PUBLIC_ID'."

# Asignar dirección IP elástica para la Puerta de Enlace NAT
echo "Creando Puerta de Enlace NAT..."
EIP_ALLOC_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --query '{AllocationId:AllocationId}' \
  --output text \
  --region $AWS_REGION)
echo "  Dirección IP elástica ID '$EIP_ALLOC_ID' ASIGNADA."

# Crear Puerta de Enlace NAT
NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $SUBNET_PUBLIC_ID \
  --allocation-id $EIP_ALLOC_ID \
  --query 'NatGateway.{NatGatewayId:NatGatewayId}' \
  --output text \
  --region $AWS_REGION)
FORMATTED_MSG="Creando la Puerta de Enlace NAT ID '$NAT_GW_ID' y esperando a que"
FORMATTED_MSG+=" esté disponible.\n    Por favor, SEA PACIENTE ya que esto puede"
FORMATTED_MSG+=" tardar un poco en completarse.\n    ......\n"
printf "  $FORMATTED_MSG"
FORMATTED_MSG="ESTADO: %s  -  %02dh:%02dm:%02ds transcurridos mientras se espera"
FORMATTED_MSG+=" que la Puerta de Enlace NAT esté disponible..."
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
  SECS=$SECONDS
  STATUS_MSG=$(printf "$FORMATTED_MSG" \
    $STATE $(($SECS/3600)) $(($SECS%3600/60)) $(($SECS%60)))
  printf "    $STATUS_MSG\033[0K\r"
  sleep 1
done
printf "\n    ......\n  Puerta de Enlace NAT ID '$NAT_GW_ID' está ahora DISPONIBLE.\n"

# Crear ruta hacia la Puerta de Enlace NAT
MAIN_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=$VPC_ID Name=association.main,Values=true \
  --query 'RouteTables[*].{RouteTableId:RouteTableId}' \
  --output text \
  --region $AWS_REGION)
echo "  La Tabla de Rutas Principal es '$MAIN_ROUTE_TABLE_ID'."
RESULT=$(aws ec2 create-route \
  --route-table-id $MAIN_ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $NAT_GW_ID \
  --region $AWS_REGION)
echo "  Ruta hacia '0.0.0.0/0' a través de la Puerta de Enlace NAT ID '$NAT_GW_ID' AÑADIDA a la Tabla de Rutas ID '$MAIN_ROUTE_TABLE_ID'."
echo "COMPLETADO"
