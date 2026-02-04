output "rbac_ready" {
  description = "RBAC 역할 할당 완료 여부"
  value       = true

  depends_on = [time_sleep.wait_for_rbac]
}
