data "aws_iam_policy_document" "aws_lbc" {
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:*",
      "ec2:Describe*",
      "ec2:Get*",
      "iam:CreateServiceLinkedRole",
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "waf-regional:*",
      "wafv2:*",
      "shield:*",
      "tag:GetResources"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "aws_lbc" {
  name   = "${var.app_name}-aws-lbc-policy"
  policy = data.aws_iam_policy_document.aws_lbc.json
}

resource "aws_iam_role" "aws_lbc" {
  name = "${var.app_name}-aws-lbc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "aws_lbc" {
  role       = aws_iam_role.aws_lbc.name
  policy_arn = aws_iam_policy.aws_lbc.arn
}
