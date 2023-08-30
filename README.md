# Practice Exercises for AWS Infrastructure Setup Using Terraform
# AWS/Terraform 間違い探し

`tf_src` 内のコードの誤りを発見し、修正してください.

1. `terraform apply` できるように修正してください.
2. `terraform apply` 後, Outputs に表示されたURLにアクセスし, nginxの画面が表示されるように修正してください.

# 注意

- AdministratorAccess 相当の権限による作業を想定しています
- AWS 利用料が発生します

# 削除

```console
$ terraform destroy
```

```console
$ aws secretsmanager delete-secret --secret-id test_app --force-delete-without-recovery
```

# 解答例 etc.

https://zenn.dev/neinc_tech/articles/4193d9953c6401