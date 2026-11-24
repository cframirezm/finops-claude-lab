---
name: revision-finops
description: Revisión FinOps semanal de una cuenta AWS a partir de la salida de scripts/find-waste.sh. Úsalo cuando la persona pegue esa salida o pida "revisión FinOps".
---

# Revisión FinOps semanal

1. Pide la salida de `scripts/find-waste.sh` si no está en la conversación. No sigas sin datos.
2. Clasifica cada recurso en un patrón: disco huérfano, gp2→gp3, snapshot viejo, IP sin usar, NAT zombi, instancia ociosa (CPU < 5% en 7 días), bucket sin ciclo de vida.
3. Para cada patrón, trae el playbook del conector Cloud FinOps (`aws-orphaned-ebs-volumes`, `aws-gp2-to-gp3`, `aws-snapshot-sprawl`, `aws-zombie-nat-gateway`, `aws-s3-incomplete-multipart-uploads`) y usa su criterio de confianza.
4. Revisa etiquetas antes que precio. Cualquier `Retention`, `DoNotDelete`, `LegalHold` u `Owner` de otra área sale de la lista de limpieza y va a "requiere aprobación".
5. Entrega la tabla del formato del proyecto, los comandos de revisión y, aparte, los de corrección marcados como `# CAMBIO`.
6. Termina con: ahorro mensual estimado, ahorro anual, y lo que no se tocó y por qué.
