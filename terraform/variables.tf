variable "region" {
  description = "Región del laboratorio"
  type        = string
  default     = "us-east-1"
}

variable "alert_email" {
  description = "Correo que recibe el reporte de la detección continua"
  type        = string
}

variable "enable_nat" {
  description = "Crea un NAT Gateway zombi (unos 1 USD por día). Actívalo solo el día de la demo."
  type        = bool
  default     = false
}

variable "detection_schedule" {
  description = "Cada cuánto corre la detección continua (por defecto, una vez al día a las 13:00 UTC)"
  type        = string
  default     = "cron(0 13 * * ? *)"
}

