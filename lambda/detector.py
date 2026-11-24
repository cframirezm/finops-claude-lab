"""Detección continua de desperdicio en AWS.

Solo lee y etiqueta (finops:candidate). Nunca borra nada.
Los precios son aproximados de us-east-1 y sirven para priorizar,
no para facturar: confirmar siempre contra la factura real.
"""
import datetime as dt
import json
import os

import boto3

ec2 = boto3.client("ec2")
s3 = boto3.client("s3")
sns = boto3.client("sns")

PRICE = {  # USD por mes, aproximado us-east-1
    "gp3_gb": 0.08,
    "gp2_gb": 0.10,
    "snapshot_gb": 0.05,
    "eip": 3.65,
    "nat": 32.85,
}
PROTECT_TAGS = {"Retention", "DoNotDelete", "LegalHold"}


def tags_of(resource):
    return {t["Key"]: t["Value"] for t in resource.get("Tags", [])}


def tag(resource_id, monthly):
    ec2.create_tags(
        Resources=[resource_id],
        Tags=[
            {"Key": "finops:candidate", "Value": "true"},
            {"Key": "finops:monthly-usd", "Value": f"{monthly:.2f}"},
        ],
    )


def find_orphan_volumes(findings, protected):
    for v in ec2.describe_volumes(Filters=[{"Name": "status", "Values": ["available"]}])["Volumes"]:
        price = PRICE["gp2_gb" if v["VolumeType"] == "gp2" else "gp3_gb"]
        monthly = v["Size"] * price
        findings.append({"tipo": "Disco huérfano", "id": v["VolumeId"], "usd_mes": monthly,
                         "detalle": f'{v["Size"]} GB {v["VolumeType"]}, sin instancia'})
        tag(v["VolumeId"], monthly)


def find_gp2(findings, protected):
    for v in ec2.describe_volumes(Filters=[{"Name": "volume-type", "Values": ["gp2"]}])["Volumes"]:
        saving = v["Size"] * (PRICE["gp2_gb"] - PRICE["gp3_gb"])
        findings.append({"tipo": "gp2 que debería ser gp3", "id": v["VolumeId"], "usd_mes": saving,
                         "detalle": "migrar a gp3 ahorra ~20% sin downtime"})


def find_snapshots(findings, protected):
    age = int(os.environ.get("SNAPSHOT_AGE_DAYS", "90"))
    limit = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=age)
    for s in ec2.describe_snapshots(OwnerIds=["self"])["Snapshots"]:
        if s["StartTime"] > limit:
            continue
        t = tags_of(s)
        if PROTECT_TAGS & t.keys():
            protected.append({"id": s["SnapshotId"], "motivo": {k: t[k] for k in PROTECT_TAGS & t.keys()}})
            continue
        monthly = s["VolumeSize"] * PRICE["snapshot_gb"]  # cota máxima: AWS cobra bloques usados
        findings.append({"tipo": "Snapshot viejo", "id": s["SnapshotId"], "usd_mes": monthly,
                         "detalle": f'de {s["VolumeId"]}, creado {s["StartTime"]:%Y-%m-%d}'})
        tag(s["SnapshotId"], monthly)


def find_unused_eips(findings, protected):
    for a in ec2.describe_addresses()["Addresses"]:
        if "AssociationId" not in a:
            findings.append({"tipo": "IP pública sin usar", "id": a["AllocationId"], "usd_mes": PRICE["eip"],
                             "detalle": a["PublicIp"]})
            tag(a["AllocationId"], PRICE["eip"])


def find_nat(findings, protected):
    for n in ec2.describe_nat_gateways(Filters=[{"Name": "state", "Values": ["available"]}])["NatGateways"]:
        findings.append({"tipo": "NAT Gateway (revisar tráfico)", "id": n["NatGatewayId"], "usd_mes": PRICE["nat"],
                         "detalle": "costo fijo por hora; confirmar si algo la usa"})
        tag(n["NatGatewayId"], PRICE["nat"])


def find_s3(findings, protected):
    for b in s3.list_buckets()["Buckets"]:
        name = b["Name"]
        try:
            s3.get_bucket_lifecycle_configuration(Bucket=name)
            has_lifecycle = True
        except s3.exceptions.ClientError:
            has_lifecycle = False
        try:
            uploads = s3.list_multipart_uploads(Bucket=name).get("Uploads", [])
        except s3.exceptions.ClientError:
            continue
        if not has_lifecycle or uploads:
            findings.append({"tipo": "Bucket sin ciclo de vida", "id": name, "usd_mes": 0.0,
                             "detalle": f"{len(uploads)} cargas multiparte incompletas; sin regla de expiración" if uploads
                             else "sin regla de ciclo de vida"})


def handler(event, context):
    findings, protected = [], []
    for check in (find_orphan_volumes, find_gp2, find_snapshots, find_unused_eips, find_nat, find_s3):
        check(findings, protected)

    total = sum(f["usd_mes"] for f in findings)
    lines = [f'- {f["tipo"]}: {f["id"]} (~{f["usd_mes"]:.2f} USD/mes) {f["detalle"]}' for f in findings]
    lines += [f'- PROTEGIDO, no tocar: {p["id"]} {p["motivo"]}' for p in protected]
    body = f"Reporte FinOps: {len(findings)} candidatos, ~{total:.2f} USD/mes.\n\n" + "\n".join(lines) + \
        "\n\nNada fue borrado. Los candidatos quedaron con la etiqueta finops:candidate=true."
    sns.publish(TopicArn=os.environ["TOPIC_ARN"], Subject="Reporte FinOps del laboratorio", Message=body)
    print(json.dumps({"findings": findings, "protected": protected}, default=str))
    return {"candidates": len(findings), "monthly_usd": round(total, 2)}
