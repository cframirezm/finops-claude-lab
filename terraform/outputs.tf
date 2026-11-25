output "bucket" {
  value = aws_s3_bucket.logs.id
}

output "detector_function" {
  value = aws_lambda_function.detector.function_name
}

output "seeded" {
  description = "Lo que se sembró, para la charla"
  value = {
    forgotten_preview = aws_ecs_service.pr_142.name
    trap_preview      = aws_ecs_service.pr_151.name
    idle_alb          = aws_lb.orphan.name
    log_groups        = concat([aws_cloudwatch_log_group.previews.name], [for g in aws_cloudwatch_log_group.old : g.name])
    ecr_repo          = aws_ecr_repository.app.name
    oversized_lambda  = aws_lambda_function.oversized.function_name
    unused_eip        = aws_eip.unused.public_ip
    zombie_nat        = try(aws_nat_gateway.zombie[0].id, "desactivado")
  }
}
