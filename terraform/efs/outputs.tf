output "efs_file_system_dns" {
  description = "EFS file system DNS"
  value       = aws_efs_file_system.ryedr_efs.dns_name
}


