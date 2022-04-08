locals {
  name            = "loftlabeks"
  cluster_version = "1.21"
  region          = var.region

  tags = {
    company = "Devoteam"
    pillar  = "ACloudGermany"
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.19.0"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_name                    = local.name
  cluster_version                 = local.cluster_version
  cluster_addons = {
    # Note: https://docs.aws.amazon.com/eks/latest/userguide/fargate-getting-started.html#fargate-gs-coredns
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  cluster_encryption_config = [{
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Allow access from control plane to webhook port of AWS load balancer controller
  # https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2462#issuecomment-1031624085
  node_security_group_additional_rules = {
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # You require a node group to schedule coredns which is critical for running correctly internal DNS.
  # If you want to use only fargate you must follow docs `(Optional) Update CoreDNS`
  # available under https://docs.aws.amazon.com/eks/latest/userguide/fargate-getting-started.html
  eks_managed_node_groups = {
    workload = {
      desired_size = 3

      instance_types = ["t2.small"]
      labels         = {}
      tags           = local.tags
    }
  }

  fargate_profiles = {
    game-2048 = {
      name = "game-2048"
      selectors = [
        { namespace = "game-2048" },
      ]
      tags = local.tags
      timeouts = {
        create = "20m"
        delete = "20m"
      }
    }
  }
}
