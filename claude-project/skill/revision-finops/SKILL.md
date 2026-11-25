---
name: revision-finops
description: Revisión FinOps de una cuenta AWS. Úsalo cuando la persona pida "revisión FinOps".
---

# Revisión FinOps semanal

1. Consulta la cuenta con el MCP de AWS (solo lectura). Si el MCP no está disponible, pide la salida de `scripts/find-waste.sh`.
2. Revisa cada patrón: entornos de preview encendidos (ECS con `Environment=preview`), balanceadores sin destinos, logs sin retención, repositorios ECR sin ciclo de vida, Lambdas con 2 GB o más, IPs sin asociar, NAT Gateways y buckets sin ciclo de vida.
3. Para cada patrón, trae el playbook del conector Cloud FinOps si existe (`aws-idle-load-balancer`, `aws-nat-gateway-endpoint-substitution`, `aws-s3-incomplete-multipart-uploads`) y usa su criterio de confianza.
4. Revisa etiquetas antes que precio. `Retention`, `DoNotDelete`, `LegalHold`, un `DoNotDelete-until` con fecha futura o un `Owner` de otra área sacan el recurso de la limpieza y lo mandan a "requiere aprobación", con a quién preguntar.
5. Si tienes acceso a Cost Explorer (MCP de costos), confirma el costo real del mes de cada servicio; si no, di que las cifras son estimadas.
6. Entrega la tabla del formato del proyecto, los comandos de revisión y, aparte, los de corrección marcados como `# CAMBIO`.
7. Termina con: ahorro mensual estimado, ahorro anual, y lo que no se tocó y por qué.
