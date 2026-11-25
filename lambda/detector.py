"""Detección continua de desperdicio DevOps en AWS.

Solo lee y etiqueta (finops:candidate). Nunca borra ni apaga nada.
Los precios son aproximados de us-east-1 y sirven para priorizar,
no para facturar: confirmar siempre en Cost Explorer o el CUR.
"""
import datetime as dt
import json
import os

import boto3

ecs = boto3.client("ecs")
elb = boto3.client("elbv2")
logs = boto3.client("logs")
ecr = boto3.client("ecr")
lam = boto3.client("lambda")
ec2 = boto3.client("ec2")
s3 = boto3.client("s3")
tagging = boto3.client("resourcegroupstaggingapi")
sns = boto3.client("sns")

PRICE = {  # USD por mes, aproximado us-east-1
    "fargate_vcpu": 29.55,   # por vCPU-mes
    "fargate_gb": 3.24,      # por GB-mes
    "alb": 16.43,            # costo fijo del ALB, sin LCU
    "eip": 3.65,
    "nat": 32.85,
}
PROTECT_KEYS = {"Retention", "DoNotDelete", "LegalHold"}
TODAY = dt.date.today()


def protection(tags):
    """Devuelve el motivo si un recurso está protegido por etiqueta."""
    hits = {k: v for k, v in tags.items() if k in PROTECT_KEYS}
    until = tags.get("DoNotDelete-until")
    if until:
        try:
            if dt.date.fromisoformat(until) >= TODAY:
                hits["DoNotDelete-until"] = until
        except ValueError:
            hits["DoNotDelete-until"] = until  # fecha ilegible: mejor no tocar
    return hits


def mark(arn, monthly):
    tagging.tag_resources(
        ResourceARNList=[arn],
        Tags={"finops:candidate": "true", "finops:monthly-usd": f"{monthly:.2f}"},
    )


def add(findings, protected, kind, arn, name, monthly, detail, tags):
    p = protection(tags)
    if p:
        protected.append({"tipo": kind, "id": name, "motivo": p})
        return
    findings.append({"tipo": kind, "id": name, "usd_mes": monthly, "detalle": detail})
    mark(arn, monthly)


def previews(findings, protected):
    for cluster in ecs.list_clusters()["clusterArns"]:
        arns = ecs.list_services(cluster=cluster)["serviceArns"]
        if not arns:
            continue
        for s in ecs.describe_services(cluster=cluster, services=arns, include=["TAGS"])["services"]:
            tags = {t["key"]: t["value"] for t in s.get("tags", [])}
            if tags.get("Environment") != "preview" or s["runningCount"] == 0:
                continue
            td = ecs.describe_task_definition(taskDefinition=s["taskDefinition"])["taskDefinition"]
            vcpu, gb = int(td["cpu"]) / 1024, int(td["memory"]) / 1024
            monthly = s["runningCount"] * (vcpu * PRICE["fargate_vcpu"] + gb * PRICE["fargate_gb"])
            pr = tags.get("PullRequest", "?")
            state = tags.get("PullRequestState", "desconocido")
            add(findings, protected, "Preview encendido", s["serviceArn"], s["serviceName"], monthly,
                f"PR #{pr} ({state}), {s['runningCount']} tarea(s) 24/7", tags)


def idle_albs(findings, protected):
    for lb in elb.describe_load_balancers()["LoadBalancers"]:
        arn = lb["LoadBalancerArn"]
        targets = 0
        for tg in elb.describe_target_groups(LoadBalancerArn=arn)["TargetGroups"]:
            targets += len(elb.describe_target_health(TargetGroupArn=tg["TargetGroupArn"])["TargetHealthDescriptions"])
        if targets:
            continue
        tags = {t["Key"]: t["Value"] for t in elb.describe_tags(ResourceArns=[arn])["TagDescriptions"][0]["Tags"]}
        add(findings, protected, "Balanceador sin destinos", arn, lb["LoadBalancerName"], PRICE["alb"],
            "0 destinos registrados; cobra la hora igual", tags)


def log_groups(findings, protected):
    for page in logs.get_paginator("describe_log_groups").paginate():
        for g in page["logGroups"]:
            if "retentionInDays" in g:
                continue
            arn = g["arn"].rstrip(":*")
            tags = logs.list_tags_for_resource(resourceArn=arn).get("tags", {})
            gb = g.get("storedBytes", 0) / 1e9
            add(findings, protected, "Logs sin retención", arn, g["logGroupName"], gb * 0.03,
                f"{gb:.3f} GB guardados para siempre", tags)


def ecr_repos(findings, protected):
    for r in ecr.describe_repositories()["repositories"]:
        try:
            ecr.get_lifecycle_policy(repositoryName=r["repositoryName"])
            continue
        except ecr.exceptions.LifecyclePolicyNotFoundException:
            pass
        tags = {t["Key"]: t["Value"] for t in ecr.list_tags_for_resource(resourceArn=r["repositoryArn"])["tags"]}
        add(findings, protected, "ECR sin ciclo de vida", r["repositoryArn"], r["repositoryName"], 0.0,
            "cada build deja una imagen que nadie borra", tags)


def oversized_lambdas(findings, protected):
    for page in lam.get_paginator("list_functions").paginate():
        for f in page["Functions"]:
            if f["MemorySize"] < 2048 or f["FunctionName"].startswith("finops-lab-"):
                continue
            tags = lam.list_tags(Resource=f["FunctionArn"]).get("Tags", {})
            add(findings, protected, "Lambda sobredimensionada (revisar)", f["FunctionArn"], f["FunctionName"], 0.0,
                f'{f["MemorySize"]} MB; comparar con la memoria usada en CloudWatch', tags)


def eips(findings, protected):
    for a in ec2.describe_addresses()["Addresses"]:
        if "AssociationId" in a:
            continue
        tags = {t["Key"]: t["Value"] for t in a.get("Tags", [])}
        arn = f'arn:aws:ec2:{os.environ["AWS_REGION"]}:{os.environ["ACCOUNT_ID"]}:elastic-ip/{a["AllocationId"]}'
        add(findings, protected, "IP pública sin usar", arn, a["PublicIp"], PRICE["eip"], a["AllocationId"], tags)


def nats(findings, protected):
    for n in ec2.describe_nat_gateways(Filters=[{"Name": "state", "Values": ["available"]}])["NatGateways"]:
        tags = {t["Key"]: t["Value"] for t in n.get("Tags", [])}
        arn = f'arn:aws:ec2:{os.environ["AWS_REGION"]}:{os.environ["ACCOUNT_ID"]}:natgateway/{n["NatGatewayId"]}'
        add(findings, protected, "NAT Gateway (revisar tráfico)", arn, n["NatGatewayId"], PRICE["nat"],
            "costo fijo por hora; ¿el tráfico a ECR/S3 podría ir por VPC endpoints?", tags)


def buckets(findings, protected):
    for b in s3.list_buckets()["Buckets"]:
        name = b["Name"]
        try:
            s3.get_bucket_lifecycle_configuration(Bucket=name)
            continue
        except s3.exceptions.ClientError:
            pass
        try:
            uploads = s3.list_multipart_uploads(Bucket=name).get("Uploads", [])
        except s3.exceptions.ClientError:
            continue
        findings.append({"tipo": "Bucket sin ciclo de vida", "id": name, "usd_mes": 0.0,
                         "detalle": f"{len(uploads)} cargas multiparte incompletas" if uploads else "sin regla de expiración"})


def handler(event, context):
    findings, protected = [], []
    for check in (previews, idle_albs, log_groups, ecr_repos, oversized_lambdas, eips, nats, buckets):
        try:
            check(findings, protected)
        except Exception as e:  # una revisión que falla no tumba las demás
            print(f"{check.__name__}: {e}")

    total = sum(f["usd_mes"] for f in findings)
    lines = [f'- {f["tipo"]}: {f["id"]} (~{f["usd_mes"]:.2f} USD/mes) {f["detalle"]}' for f in findings]
    lines += [f'- PROTEGIDO, no tocar: {p["tipo"]} {p["id"]} {p["motivo"]}' for p in protected]
    body = (f"Reporte FinOps: {len(findings)} candidatos, ~{total:.2f} USD/mes.\n\n" + "\n".join(lines) +
            "\n\nNada fue borrado ni apagado. Los candidatos quedaron con la etiqueta finops:candidate=true.")
    sns.publish(TopicArn=os.environ["TOPIC_ARN"], Subject="Reporte FinOps del laboratorio", Message=body)
    print(json.dumps({"findings": findings, "protected": protected}, default=str))
    return {"candidates": len(findings), "protected": len(protected), "monthly_usd": round(total, 2)}
