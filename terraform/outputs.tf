output "bucket" {
  value = aws_s3_bucket.logs.id
}

output "detector_function" {
  value = aws_lambda_function.detector.function_name
}

output "seeded" {
  description = "Lo que se sembró, para la charla"
  value = {
    orphan_volume   = aws_ebs_volume.orphan.id
    gp2_volume      = aws_ebs_volume.gp2.id
    snapshots       = aws_ebs_snapshot.sprawl[*].id
    trap_snapshot   = aws_ebs_snapshot.only_backup.id
    unused_eip      = aws_eip.unused.public_ip
    idle_instance   = aws_instance.idle.id
    zombie_nat      = try(aws_nat_gateway.zombie[0].id, "desactivado")
  }
}
