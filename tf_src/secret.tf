resource "aws_secretsmanager_secret" "test_app_keys" {
  name = local.name
}

resource "aws_secretsmanager_secret_version" "dummy" {
  secret_id     = aws_secretsmanager_secret.test_app_keys.id
  secret_string = "dummy-string"
}
