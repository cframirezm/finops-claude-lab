#!/usr/bin/env bash
# Plan B de la demo: detección manual de solo lectura.
# Corre en CloudShell y pégale la salida a Claude si el MCP falla.
set -uo pipefail
R=${AWS_REGION:-us-east-1}
echo "== Servicios ECS de preview encendidos =="
for c in $(aws ecs list-clusters --region "$R" --query 'clusterArns[]' --output text); do
  s=$(aws ecs list-services --region "$R" --cluster "$c" --query 'serviceArns[]' --output text)
  [ -z "$s" ] && continue
  aws ecs describe-services --region "$R" --cluster "$c" --services $s --include TAGS \
    --query 'services[].{servicio:serviceName,corriendo:runningCount,tags:tags}' --output json
done
echo "== Balanceadores y cuántos destinos tienen =="
for lb in $(aws elbv2 describe-load-balancers --region "$R" --query 'LoadBalancers[].LoadBalancerArn' --output text); do
  n=0
  for tg in $(aws elbv2 describe-target-groups --region "$R" --load-balancer-arn "$lb" --query 'TargetGroups[].TargetGroupArn' --output text); do
    n=$((n + $(aws elbv2 describe-target-health --region "$R" --target-group-arn "$tg" --query 'length(TargetHealthDescriptions)' --output text)))
  done
  echo "$(basename "$lb")  destinos: $n"
done
echo "== Grupos de logs sin retención =="
aws logs describe-log-groups --region "$R" \
  --query 'logGroups[?retentionInDays==null].{grupo:logGroupName,bytes:storedBytes}' --output table
echo "== Repositorios ECR y su política de ciclo de vida =="
for r in $(aws ecr describe-repositories --region "$R" --query 'repositories[].repositoryName' --output text); do
  aws ecr get-lifecycle-policy --region "$R" --repository-name "$r" >/dev/null 2>&1 && lc="sí" || lc="NO"
  echo "$r  ciclo de vida: $lc"
done
echo "== Lambdas con 2 GB o más de memoria =="
aws lambda list-functions --region "$R" \
  --query 'Functions[?MemorySize>=`2048`].{funcion:FunctionName,mb:MemorySize}' --output table
echo "== IPs públicas sin asociar =="
aws ec2 describe-addresses --region "$R" \
  --query 'Addresses[?AssociationId==null].{ip:PublicIp,id:AllocationId}' --output table
echo "== NAT Gateways activas =="
aws ec2 describe-nat-gateways --region "$R" --filter Name=state,Values=available \
  --query 'NatGateways[].{id:NatGatewayId,subred:SubnetId}' --output table
echo "== Buckets: ciclo de vida y cargas incompletas =="
for b in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
  lc=$(aws s3api get-bucket-lifecycle-configuration --bucket "$b" >/dev/null 2>&1 && echo "sí" || echo "NO")
  mp=$(aws s3api list-multipart-uploads --bucket "$b" --query 'length(Uploads || `[]`)' --output text 2>/dev/null)
  echo "$b  ciclo de vida: $lc  cargas incompletas: $mp"
done
