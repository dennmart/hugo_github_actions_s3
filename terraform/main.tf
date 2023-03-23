terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.59.0"
    }
  }
}

# Sets up the GitHub identity provider. More information can
# be found in the following page:
# https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
resource "aws_iam_openid_connect_provider" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

# Creates an IAM policy to allow GitHub Actions to put objects
# in an S3 bucket to attach to an IAM role.
resource "aws_iam_policy" "github_actions_policy" {
  name        = "S3GitHubActionsPolicy"
  description = "Policy to allow GitHub Actions to put objects in the dennis-static-site S3 bucket."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:ListBucket"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::dennis-static-site"
        ]
      },
      {
        "Action" : [
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::dennis-static-site/*"
        ]
      }
    ]
  })
}

# Creates an IAM role with the policy created above attached,
# and allows the GitHub OIDC provider to assume the role.
resource "aws_iam_role" "github_actions_role" {
  name                = "S3GitHubActionsRole"
  description         = "Role to use for GitHub Actions."
  managed_policy_arns = [aws_iam_policy.github_actions_policy.arn]

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Federated" : aws_iam_openid_connect_provider.github_oidc.arn
          },
          "Action" : "sts:AssumeRoleWithWebIdentity",
          "Condition" : {
            "StringEquals" : {
              "token.actions.githubusercontent.com:aud" : aws_iam_openid_connect_provider.github_oidc.client_id_list[0]
            }
          }
        }
      ]
    }
  )
}
