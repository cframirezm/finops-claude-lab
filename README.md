# FinOps con IA: laboratorio

Laboratorio para la charla **"FinOps con IA: encontrar el desperdicio en tu cuenta AWS sin darle las llaves a la IA"**.

Siembra desperdicio típico en una cuenta AWS de pruebas, lo detecta de dos formas (a mano con Claude y de forma continua con una Lambda) y muestra cómo decidir qué limpiar sin romper nada.

> **Solo para una cuenta de laboratorio.** Crea recursos que cobran a propósito. Destrúyelo al terminar.

## Qué se siembra

Desperdicio de una plataforma DevOps moderna: contenedores, serverless y pipelines.

| Desperdicio | Recurso | Playbook del conector Cloud FinOps |
|---|---|---|
| Entorno de preview olvidado | ECS Fargate `preview-pr-142` (PR cerrado), encendido 24/7 | schedule blindness |
| **La trampa** | ECS Fargate `preview-pr-151`, con `DoNotDelete-until` y `Owner=qa` | — |
| Balanceador sin destinos | ALB `legacy-api-alb` con 0 targets | `aws-idle-load-balancer` |
| Logs que nunca expiran | 3 grupos de CloudWatch Logs sin retención | — |
| Imágenes acumuladas | Repositorio ECR sin política de ciclo de vida | — |
| Lambda sobredimensionada | `thumbnail-resizer` con 3 GB de memoria | — |
| IP pública sin usar | Elastic IP sin asociar | — |
| Artefactos sin ciclo de vida | S3 con cargas multiparte incompletas | `aws-s3-incomplete-multipart-uploads` |
| NAT para descargar imágenes (opcional) | NAT Gateway | `aws-nat-gateway-endpoint-substitution` |

Costo aproximado: 2 a 3 USD por día (ALB y Fargate). Con `enable_nat=true`, unos 1 USD por día más.

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

Detección continua: la Lambda `finops-lab-detector` corre una vez al día, etiqueta los candidatos con `finops:candidate=true` y manda el reporte por correo. **Nunca borra.** Los recursos con `Retention`, `DoNotDelete` o `LegalHold` aparecen como protegidos.

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
