#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EC2 Security Group to allow networking traffic
#  * Data source to fetch latest EKS worker AMI
#  * AutoScaling Launch Configuration to configure worker instances
#  * AutoScaling Group to launch worker instances
#

resource "aws_iam_role" "devops-node" {
  name = "terraform-eks-${local.resource_prefix}-node-iam-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "devops-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.devops-node.name}"
}

resource "aws_iam_role_policy_attachment" "devops-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.devops-node.name}"
}

resource "aws_iam_role_policy_attachment" "devops-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.devops-node.name}"
}

resource "aws_iam_instance_profile" "devops-node" {
  name = "terraform-eks-${local.resource_prefix}-instance-profile"
  role = "${aws_iam_role.devops-node.name}"
}

resource "aws_security_group" "devops-node" {
  name        = "terraform-eks-${local.resource_prefix}-node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = tolist(data.aws_vpcs.main.ids)[0]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
      "Name", "terraform-eks-devops-node-${local.resource_prefix}",
      "kubernetes.io/cluster/terraform-eks-${local.resource_prefix}", "owned",
    )
  }"
}

resource "aws_security_group_rule" "devops-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.devops-node.id}"
  source_security_group_id = "${aws_security_group.devops-node.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "devops-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.devops-node.id}"
  source_security_group_id = "${aws_security_group.devops-cluster.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node-port-ingress" {
  description       = "Allow incomming traffic to the nodes so that services can be accessed via NodePort"
  security_group_id = "${aws_security_group.devops-node.id}"
  protocol          = "tcp"
  from_port         = "30000"
  to_port           = "32767"
  type              = "ingress"
  cidr_blocks       = ["${local.cloud9-external-cidr}", "${local.workstation-external-cidr}"]
}

data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.devops.version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  devops-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.devops.endpoint}' --b64-cluster-ca '${aws_eks_cluster.devops.certificate_authority.0.data}' 'terraform-eks-${local.resource_prefix}'
USERDATA
}

resource "aws_launch_configuration" "devops" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.devops-node.name}"
  image_id                    = "${data.aws_ami.eks-worker.id}"
  instance_type               = "t3.medium"
  name_prefix                 = "terraform-eks-devops-${local.resource_prefix}"
  security_groups             = ["${aws_security_group.devops-node.id}"]
  user_data_base64            = "${base64encode(local.devops-node-userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "devops" {
  desired_capacity     = 2
  launch_configuration = "${aws_launch_configuration.devops.id}"
  max_size             = 2
  min_size             = 1
  name                 = "terraform-eks-${local.resource_prefix}-asg"
  vpc_zone_identifier  = data.aws_subnet_ids.subnets.ids

  tag {
    key                 = "Name"
    value               = "terraform-eks-devops"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/terraform-eks-${local.resource_prefix}"
    value               = "owned"
    propagate_at_launch = true
  }
}
