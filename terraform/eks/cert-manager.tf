resource "aws_iam_user" "dns-manager" {
  name = "dns-manager-${local.resource_prefix}"

  tags = {
    Owner = "${var.owner}"
  }
}
resource "aws_iam_access_key" "dns-manager" {
  user = "${aws_iam_user.dns-manager.name}"
}

resource "aws_iam_user_policy" "dns-manager-policy" {
  name = "dns-manager-user-policy-${local.resource_prefix}"
  user = "${aws_iam_user.dns-manager.name}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "route53:GetChange",
            "Resource": "arn:aws:route53:::change/*"
        },
        {
            "Effect": "Allow",
            "Action": "route53:ChangeResourceRecordSets",
            "Resource": "arn:aws:route53:::hostedzone/*"
        },
        {
            "Effect": "Allow",
            "Action": "route53:ListHostedZonesByName",
            "Resource": "*"
        }
    ]
}
EOF
}

output "secret-key" {
  value = "${aws_iam_access_key.dns-manager.secret}"
}

output "access-key" {
  value = "${aws_iam_access_key.dns-manager.id}"
}
