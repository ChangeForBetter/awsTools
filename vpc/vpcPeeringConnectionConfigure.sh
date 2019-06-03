#!/bin/bash

vpcId=$1
peerVpcId=$2
tagName=${$3:-$vpcId---$peerVpcId}

echo "1.create vpc peering connection between $vpcId and $peerVpcId"
tmpFile=/tmp/create-vpc-peering-connection
aws ec2 create-vpc-peering-connection --vpc-id $vpcId --peer-vpc-id $peerVpcId > $tmpFile

echo "2.get vpc peering connection id"
vpcPeeringConnectionId=$(jq --raw-output '.VpcPeeringConnection.VpcPeeringConnectionId' $tmpFile)
echo "$vpcPeeringConnectionId"

echo "3.accept vpc peering connection"
tmpFile=/tmp/accept-vpc-peering-connection
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $vpcPeeringConnectionId > $tmpFile

echo "4.get requesterVpcCidrBlockSet and accepterCidrBlockSet"
requesterVpcCidrBlockSet=$(jq --raw-output '.VpcPeeringConnection.RequesterVpcInfo.CidrBlockSet[] | .CidrBlock' $tmpFile)
accepterVpcCidrBlockSet=$(jq --raw-output '.VpcPeeringConnection.AccepterVpcInfo.CidrBlockSet[] | .CidrBlock' $tmpFile)

echo "5.get requesterVpcRouteTableIds and accepterVpcRouteTableIds by vpc-id"
tmpFile=/tmp/describe-route-tables
aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpcId,$peerVpcId > $tmpFile
requesterVpcRouteTableIds=$(jq --raw-output '.RouteTables[] | select(.VpcId == "'$vpcId'") | .RouteTableId' $tmpFile)
accepterVpcRouteTableIds=$(jq --raw-output '.RouteTables[] | select(.VpcId == "'$peerVpcId'") | .RouteTableId' $tmpFile)

echo "6.Add route to route table"
for routeTableId in $requesterVpcRouteTableIds; do
    echo "route table: $routeTableId"
    for cidrBlock in $accepterVpcCidrBlockSet; do
        echo "$cidrBlock --> $vpcPeeringConnectionId"
        aws ec2 create-route --route-table-id $routeTableId --destination-cidr-block $cidrBlock --vpc-peering-connection-id $vpcPeeringConnectionId
    done
done

for routeTableId in $accepterVpcRouteTableIds; do
    echo "route table: $routeTableId"
    for cidrBlock in $requesterVpcCidrBlockSet; do
        echo "$cidrBlock --> $vpcPeeringConnectionId"
        aws ec2 create-route --route-table-id $routeTableId --destination-cidr-block $cidrBlock --vpc-peering-connection-id $vpcPeeringConnectionId
    done
done

echo "7.Add tags $tagName"
aws ec2 create-tags --resources $vpcPeeringConnectionId --tags Key=Name,Value=$tagName
