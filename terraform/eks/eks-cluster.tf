#
# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster
#

resource "aws_iam_role" "devops-cluster" {
  name = "terraform-eks-${local.resource_prefix}-iam-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "devops-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.devops-cluster.name}"
}

resource "aws_iam_role_policy_attachment" "devops-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.devops-cluster.name}"
}

resource "aws_security_group" "devops-cluster" {
  name        = "terraform-eks-${local.resource_prefix}"
  description = "Cluster communication with worker nodes"
  vpc_id      = tolist(data.aws_vpcs.main.ids)[0]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-eks-${local.resource_prefix}"
  }
}

resource "aws_security_group_rule" "devops-cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.devops-cluster.id}"
  source_security_group_id = "${aws_security_group.devops-node.id}"
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "devops-cluster-ingress-workstation-https" {
  cidr_blocks       = ["${local.workstation-external-cidr}"]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.devops-cluster.id}"
  to_port           = 443
  type              = "ingress"
}

resource "aws_eks_cluster" "devops" {
  name     = "terraform-eks-${local.resource_prefix}"
  role_arn = "${aws_iam_role.devops-cluster.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.devops-cluster.id}"]
    subnet_ids         = data.aws_subnet_ids.subnets.ids
  }

  depends_on = [
    "aws_iam_role_policy_attachment.devops-cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.devops-cluster-AmazonEKSServicePolicy",
  ]
}
