# FinOps con IA: laboratorio

Laboratorio para la charla **"FinOps con IA: encontrar el desperdicio en tu cuenta AWS sin darle las llaves a la IA"**.

Siembra desperdicio típico en una cuenta AWS de pruebas, lo detecta de dos formas (a mano con Claude y de forma continua con una Lambda) y muestra cómo decidir qué limpiar sin romper nada.

> **Solo para una cuenta de laboratorio.** Crea recursos que cobran a propósito. Destrúyelo al terminar.

## Qué se siembra

| Desperdicio | Recurso | Playbook del conector Cloud FinOps |
|---|---|---|
| Disco huérfano | EBS de 20 GB sin instancia | `aws-orphaned-ebs-volumes` |
| gp2 en vez de gp3 | EBS gp2 de 10 GB | `aws-gp2-to-gp3` |
| Snapshots acumulados | 3 snapshots del disco huérfano | `aws-snapshot-sprawl` |
| **La trampa** | Snapshot `billing-db-final-backup` con retención legal | `aws-snapshot-sprawl` |
| IP pública sin usar | Elastic IP sin asociar | — |
| Instancia ociosa | t3.micro encendida sin carga | — |
| Bucket sin ciclo de vida | S3 con logs y cargas multiparte incompletas | `aws-s3-incomplete-multipart-uploads` |
| NAT zombi (opcional) | NAT Gateway sin tráfico | `aws-zombie-nat-gateway` |

Costo aproximado: 1 a 2 USD por día. Con `enable_nat=true`, unos 1 USD por día más.

## Cómo se usa

```bash
cd terraform
terraform init
terraform apply -var alert_email=tu@correo.com      # confirma la suscripción SNS en tu correo
../scripts/seed-s3.sh                               # siembra las cargas multiparte incompletas
```

Detección manual con Claude:
```bash
../scripts/find-waste.sh     # solo lectura; pega la salida en tu proyecto de Claude
```

Detección continua: la Lambda `finops-lab-detector` corre cada hora, etiqueta los candidatos con `finops:candidate=true` y manda el reporte por correo. **Nunca borra.** Los recursos con `Retention`, `DoNotDelete` o `LegalHold` aparecen como protegidos.

Al terminar:
```bash
terraform destroy -var alert_email=tu@correo.com
```

## El proyecto de Claude

En `claude-project/` está todo para armar tu propio "FinOps Copilot":
- `instrucciones.md`: pégalo en las instrucciones de un proyecto.
- `conocimiento/`: súbelo como conocimiento del proyecto y adáptalo a tu empresa.
- `skill/revision-finops/`: un skill para la revisión semanal.

Activa también el conector **Cloud FinOps** (de OptimNow, no de AWS ni de Anthropic). Trae los playbooks y sus consultas de detección. El conector no tiene acceso a tu cuenta: tú corres los comandos.

## Principio

La IA propone, tú ejecutas. Primero se lee, después se etiqueta y al final se decide.
