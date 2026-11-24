# Políticas de la cuenta (ejemplo del laboratorio)

Adapta este documento a tu empresa y súbelo como conocimiento del proyecto.

## Etiquetas obligatorias
- `Owner`: área responsable (finanzas, plataforma, datos…).
- `Environment`: prod, staging o dev.
- `Retention`: si existe, el recurso tiene una obligación de conservación. **No se borra sin aprobación de Owner.**

## Qué se puede limpiar sin aprobación
- Recursos de `Environment=dev` con más de 30 días sin uso.
- Discos sin instancia de dev, después de tomarles snapshot.
- IPs públicas sin asociar.

## Qué necesita aprobación
- Cualquier recurso de `prod`.
- Snapshots con `Retention` o con nombre que diga backup, final o legal.
- NAT Gateways y balanceadores: primero confirmar que nada depende de ellos.

## Recursos críticos conocidos (laboratorio)
- `billing-db-final-backup`: único respaldo de la base de facturación 2025. Retención legal de 7 años. Owner: finanzas.

## Cómo se aprueba un cambio
Ticket en el sistema de cambios con: recurso, costo mensual, riesgo y plan de reversa.
