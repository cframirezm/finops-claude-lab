#!/usr/bin/env bash
# Detección manual, de solo lectura. Corre en CloudShell y pégale la salida a Claude.
set -uo pipefail
R=${AWS_REGION:-us-east-1}
echo "== Discos sin instancia =="
aws ec2 describe-volumes --region "$R" --filters Name=status,Values=available \
  --query 'Volumes[].{id:VolumeId,gb:Size,tipo:VolumeType,tags:Tags}' --output json
echo "== Discos gp2 =="
aws ec2 describe-volumes --region "$R" --filters Name=volume-type,Values=gp2 \
  --query 'Volumes[].{id:VolumeId,gb:Size,estado:State}' --output table
echo "== Snapshots propios =="
aws ec2 describe-snapshots --region "$R" --owner-ids self \
  --query 'Snapshots[].{id:SnapshotId,gb:VolumeSize,fecha:StartTime,tags:Tags}' --output json
echo "== IPs públicas sin asociar =="
aws ec2 describe-addresses --region "$R" \
  --query 'Addresses[?AssociationId==null].{ip:PublicIp,id:AllocationId}' --output table
echo "== NAT Gateways activas =="
aws ec2 describe-nat-gateways --region "$R" --filter Name=state,Values=available \
  --query 'NatGateways[].{id:NatGatewayId,subred:SubnetId}' --output table
echo "== Instancias encendidas y su CPU promedio (7 días) =="
for id in $(aws ec2 describe-instances --region "$R" --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].InstanceId' --output text); do
  cpu=$(aws cloudwatch get-metric-statistics --region "$R" --namespace AWS/EC2 --metric-name CPUUtilization \
    --dimensions Name=InstanceId,Value="$id" --statistics Average --period 604800 \
    --start-time "$(date -u -d '-7 days' +%FT%TZ)" --end-time "$(date -u +%FT%TZ)" \
    --query 'Datapoints[0].Average' --output text)
  echo "$id  CPU promedio: $cpu %"
done
echo "== Buckets: ciclo de vida y cargas incompletas =="
for b in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
  lc=$(aws s3api get-bucket-lifecycle-configuration --bucket "$b" >/dev/null 2>&1 && echo "sí" || echo "NO")
  mp=$(aws s3api list-multipart-uploads --bucket "$b" --query 'length(Uploads || `[]`)' --output text 2>/dev/null)
  echo "$b  ciclo de vida: $lc  cargas incompletas: $mp"
done
