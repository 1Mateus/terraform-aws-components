locals {
  enabled = module.this.enabled
}

module "alb_controller" {
  source  = "cloudposse/helm-release/aws"
  version = "0.7.0"

  name            = "" # avoids hitting length restrictions on IAM Role names
  chart           = var.chart
  repository      = var.chart_repository
  description     = var.chart_description
  chart_version   = var.chart_version
  wait            = true # required for installing IngressClassParams
  atomic          = var.atomic
  cleanup_on_fail = var.cleanup_on_fail
  timeout         = var.timeout

  create_namespace_with_kubernetes = var.create_namespace
  kubernetes_namespace             = var.kubernetes_namespace
  kubernetes_namespace_labels      = merge(module.this.tags, { name = var.kubernetes_namespace })

  eks_cluster_oidc_issuer_url = replace(module.eks.outputs.eks_cluster_identity_oidc_issuer, "https://", "")

  service_account_name      = module.this.name
  service_account_namespace = var.kubernetes_namespace

  iam_role_enabled = true
  # https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.2.1/docs/install/iam_policy.json
  iam_policy_statements = [
    {
      sid       = "AllowCreateServiceLinkedRole"
      effect    = "Allow"
      resources = ["*"]

      actions = ["iam:CreateServiceLinkedRole"]
      conditions = [
        {
          test     = "StringEquals"
          variable = "AWSServiceName"
          values   = ["elasticloadbalancing.amazonaws.com"]
        }
      ]
    },
    {
      sid       = "AllowManageCompute"
      effect    = "Allow"
      resources = ["*"]

      actions = [
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeVpcs",
        "ec2:DescribeVpcPeeringConnections",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeTags",
        "ec2:GetCoipPoolUsage",
        "ec2:DescribeCoipPools",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeListenerCertificates",
        "elasticloadbalancing:DescribeSSLPolicies",
        "elasticloadbalancing:DescribeRules",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetGroupAttributes",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:DescribeTags",
      ]
    },
    {
      sid       = "AllowManageAuxiliaryServices"
      effect    = "Allow"
      resources = ["*"]

      actions = [
        "cognito-idp:DescribeUserPoolClient",
        "acm:ListCertificates",
        "acm:DescribeCertificate",
        "iam:ListServerCertificates",
        "iam:GetServerCertificate",
        "waf-regional:GetWebACL",
        "waf-regional:GetWebACLForResource",
        "waf-regional:AssociateWebACL",
        "waf-regional:DisassociateWebACL",
        "wafv2:GetWebACL",
        "wafv2:GetWebACLForResource",
        "wafv2:AssociateWebACL",
        "wafv2:DisassociateWebACL",
        "shield:GetSubscriptionState",
        "shield:DescribeProtection",
        "shield:CreateProtection",
        "shield:DeleteProtection",
      ]
    },
    {
      sid       = "AllowManageSGIngress"
      effect    = "Allow"
      resources = ["*"]

      actions = [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
      ]
    },
    {
      sid       = "AllowCreateSG"
      effect    = "Allow"
      resources = ["*"]
      actions   = ["ec2:CreateSecurityGroup"]
    },
    {
      sid       = "AllowManageSGTagsOnCreation"
      effect    = "Allow"
      resources = ["arn:aws:ec2:*:*:security-group/*"]
      actions   = ["ec2:CreateTags"]

      conditions = [
        {
          test     = "StringEquals"
          variable = "ec2:CreateAction"
          values   = ["CreateSecurityGroup"]
        },
        {
          test     = "Null"
          variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
          values   = ["false"]
        }
      ]
    },
    {
      sid       = "AllowManageSGTags"
      effect    = "Allow"
      resources = ["arn:aws:ec2:*:*:security-group/*"]

      actions = [
        "ec2:CreateTags",
        "ec2:DeleteTags",
      ]

      conditions = [
        {
          test     = "Null"
          variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
          values   = ["true"]
        },
        {
          test     = "Null"
          variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
          values   = ["false"]
        }
      ]
    },
    {
      sid       = "AllowManageSG"
      effect    = "Allow"
      resources = ["*"]

      actions = [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DeleteSecurityGroup",
      ]

      conditions = [
        {
          test     = "Null"
          variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
          values   = ["false"]
        }
      ]
    },
    {
      sid       = "AllowCreateLB"
      effect    = "Allow"
      resources = ["*"]

      actions = [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateTargetGroup",
      ]

      conditions = [
        {
          test     = "Null"
          variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
          values   = ["false"]
        }
      ]
    },
    {
      sid       = "AllowManageLBListeners"
      effect    = "Allow"
      resources = ["*"]

      actions = [
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:CreateRule",
        "elasticloadbalancing:DeleteRule",
      ]
    },
    {
      sid    = "AllowManageLBTags"
      effect = "Allow"

      resources = [
        "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
      ]

      actions = [
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags",
      ]

      conditions = [
        {
          test     = "Null"
          variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
          values   = ["true"]
        },
        {
          test     = "Null"
          variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
          values   = ["false"]
        }
      ]
    },
    {
      sid    = "AllowManageLBListenerTags"
      effect = "Allow"

      resources = [
        "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*",
      ]

      actions = [
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags",
      ]
    },
    {
      sid       = "AllowManageTargetGroups"
      effect    = "Allow"
      resources = ["*"]

      actions = [
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:SetIpAddressType",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:SetSubnets",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:DeleteTargetGroup",
      ]

      conditions = [
        {
          test     = "Null"
          variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
          values   = ["false"]
        }
      ]
    },
    {
      sid    = "AllowAddTagsOnCreate"
      effect = "Allow"

      resources = [
        "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
      ]

      actions = ["elasticloadbalancing:AddTags"]

      conditions = [
        {
          test     = "StringEquals"
          variable = "elasticloadbalancing:CreateAction"

          values = [
            "CreateTargetGroup",
            "CreateLoadBalancer",
            # See https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2692#issuecomment-1426242236
            "CreateListener",
          ]
        },
        {
          test     = "Null"
          variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
          values   = ["false"]
        }
      ]
    },
    {
      sid       = "AllowRegisterTargets"
      effect    = "Allow"
      resources = ["arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"]

      actions = [
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
      ]
    },
    {
      sid       = "AllowManageListenerCertificates"
      effect    = "Allow"
      resources = ["*"]

      actions = [
        "elasticloadbalancing:SetWebAcl",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:AddListenerCertificates",
        "elasticloadbalancing:RemoveListenerCertificates",
        "elasticloadbalancing:ModifyRule",
      ]
    }
  ]

  values = compact([
    # standard k8s object settings
    yamlencode({
      fullnameOverride = module.this.name,
      serviceAccount = {
        name = module.this.name
      },
      resources = var.resources
      rbac = {
        create = var.rbac_enabled
      }
    }),
    # alb-controller-specific values
    yamlencode({
      aws = {
        region = var.region
      }
      clusterName                = module.eks.outputs.eks_cluster_id
      createIngressClassResource = var.default_ingress_enabled
      ingressClass               = var.default_ingress_class_name
      ingressClassParams = {
        name    = var.default_ingress_class_name
        create  = var.default_ingress_enabled
        default = true
        spec = {
          group = {
            name = var.default_ingress_group
          }
          scheme                 = var.default_ingress_scheme
          ipAddressType          = var.default_ingress_ip_address_type
          tags                   = [for k, v in merge(module.this.tags, var.default_ingress_additional_tags) : { key = k, value = v }]
          loadBalancerAttributes = var.default_ingress_load_balancer_attributes
        }
      }
      defaultTags = module.this.tags
    }),
    # additional values
    yamlencode(var.chart_values)
  ])

  context = module.this.context
}
