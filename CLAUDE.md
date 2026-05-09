# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
terraform init        # required after adding/changing providers
terraform validate    # check configuration is syntactically valid
terraform fmt         # format all .tf files
terraform plan        # preview changes before applying
terraform apply       # deploy infrastructure
terraform destroy     # tear down all resources
```

Target a single resource:
```bash
terraform apply -target=module.eks
terraform apply -target=helm_release.aws_lbc
```

Override a variable at runtime:
```bash
terraform apply -var="desired_nodes=3" -var="node_instance_type=t3.medium"
```

Connect kubectl to the cluster:
```bash
aws eks update-kubeconfig --region us-east-1 --name myapp-eks
```

Useful kubectl commands:
```bash
kubectl get nodes                  # check worker nodes are Ready
kubectl get pods                   # check app pods are running
kubectl get ingress                # get ALB DNS name
kubectl describe ingress flask-eks # troubleshoot ALB provisioning
kubectl logs <pod-name>            # view app logs
kubectl rollout status deployment/flask-eks  # check deployment progress
```

## Architecture

A single-app EKS deployment with the following traffic flow:

```
Internet → ALB (public subnets) → Kubernetes Service → Pods (private subnets)
                                                             ↓
                                                        ECR (image source)
```

- **ALB** is created automatically by the AWS Load Balancer Controller when an Ingress resource is applied. Defined in `k8s/ingress.yaml`.
- **Pods** run in private subnets on EC2 worker nodes. Outbound traffic routes through a NAT Gateway.
- **AWS Load Balancer Controller** runs inside the cluster (installed via Helm) and watches for Ingress resources to provision ALBs.
- **IRSA** (IAM Roles for Service Accounts) gives the Load Balancer Controller pod permission to call AWS APIs without static credentials.
- **ECR** repository is created by Terraform. The CI/CD pipeline builds and pushes the image on every push to `main`.

## File Layout

| File | Purpose |
|---|---|
| `providers.tf` | AWS (~> 5.95), kubernetes, and helm provider versions |
| `variables.tf` | All input variables with defaults (`region`, `cluster_name`, `app_name`, `node_instance_type`, `desired_nodes`, `container_port`) |
| `vpc.tf` | VPC, public/private subnets, NAT Gateway. Subnet tags required for ALB discovery |
| `eks.tf` | EKS cluster and managed node group (auto-scaling min 1, max 3) |
| `iam.tf` | IAM policy and IRSA role for Load Balancer Controller; EKS access for github-actions-deployer |
| `helm.tf` | Installs aws-load-balancer-controller chart into kube-system namespace |
| `ecr.tf` | ECR repository for the Flask app image |
| `outputs.tf` | `cluster_name`, `cluster_endpoint`, `ecr_repository_url`, `configure_kubectl` |
| `k8s/deployment.yaml` | Kubernetes Deployment — 2 replicas, image replaced by CI/CD pipeline |
| `k8s/service.yaml` | ClusterIP Service — internal routing to pods on port 8080 |
| `k8s/ingress.yaml` | Ingress — triggers ALB creation, routes HTTP:80 to the service |

## CI/CD

The app repo (`markovicivan1987/myapp-eks`) contains the GitHub Actions pipeline at `.github/workflows/deploy.yml`. On every push to `main`:
1. Checks out this infrastructure repo to get `k8s/` manifests (Option B pattern)
2. Builds and pushes Docker image to ECR with the commit SHA as tag
3. Replaces `PLACEHOLDER` in `k8s/deployment.yaml` with the real image URL
4. Runs `kubectl apply -f infra/k8s/` to deploy

GitHub Secrets required in the app repo: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.

## Key Design Decisions

- **State is local** — no remote backend configured. Intentional for personal/test use.
- **`bootstrap_self_managed_addons = false`** — must be set explicitly to match the cluster created during the initial interrupted apply. Without it Terraform tries to replace the cluster.
- **Option B for k8s manifests** — manifests live in this infra repo, not the app repo. The pipeline checks out this repo at deploy time to avoid duplicating manifests.
- **`force_delete = true` on ECR** — allows `terraform destroy` to succeed even when images exist.
- **Subnet tags** — `kubernetes.io/role/elb = 1` on public subnets and `kubernetes.io/role/internal-elb = 1` on private subnets are required for the Load Balancer Controller to discover where to place the ALB.
- **AWS provider pinned to ~> 5.95** — the EKS module (~> 20.0) requires `aws >= 5.95, < 6.0`. Using `~> 6.0` causes a version conflict during `terraform init`.
