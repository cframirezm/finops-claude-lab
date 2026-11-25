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
- Recursos con `Retention`, `DoNotDelete` o `DoNotDelete-until` con fecha futura.
- NAT Gateways y balanceadores: primero confirmar que nada depende de ellos.

## Recursos críticos conocidos (laboratorio)
- `preview-pr-151` (ECS, clúster previews): QA lo usa para validar el release de diciembre de 2026. Etiqueta `DoNotDelete-until: 2026-12-10`. Owner: qa.

## Cómo se aprueba un cambio
Ticket en el sistema de cambios con: recurso, costo mensual, riesgo y plan de reversa.
