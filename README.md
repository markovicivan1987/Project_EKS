# Project_EKS

Terraform infrastructure for deploying a Flask app on AWS EKS (Elastic Kubernetes Service).

## Architecture

```
Internet → ALB (public subnets) → Kubernetes Service → Pods (private subnets)
                                                             ↓
                                                        ECR (image source)
```

- **EKS** manages the Kubernetes control plane and worker nodes (EC2 t3.small, auto-scaling 1-3)
- **ALB** is provisioned automatically by the AWS Load Balancer Controller when an Ingress is applied
- **IRSA** gives the Load Balancer Controller pod AWS permissions without static credentials
- **ECR** stores the Docker image built and pushed by the CI/CD pipeline

## Usage

```bash
terraform init
terraform plan
terraform apply
```

Configure kubectl after apply:
```bash
aws eks update-kubeconfig --region us-east-1 --name myapp-eks
```

## Destroying

**Important:** Before running `terraform destroy`, delete the Ingress first so the Load Balancer Controller removes the ALB. If you skip this, Terraform will fail with `DependencyViolation` on the subnets and VPC.

```bash
kubectl delete ingress flask-eks
# wait ~1-2 minutes for the ALB to be removed
terraform destroy
```

If you forgot and terraform destroy failed, manually delete the ALB and any `k8s-` prefixed security groups from the AWS console, then run `terraform destroy` again.

## App Repository

Application code and CI/CD pipeline:
[myapp-eks](https://github.com/markovicivan1987/myapp-eks)

## File Layout

| File | Purpose |
|---|---|
| `providers.tf` | AWS, kubernetes, and helm provider versions |
| `variables.tf` | Input variables with defaults |
| `vpc.tf` | VPC, subnets, NAT Gateway |
| `eks.tf` | EKS cluster and managed node group |
| `iam.tf` | IAM roles for Load Balancer Controller (IRSA) and github-actions-deployer |
| `helm.tf` | Installs AWS Load Balancer Controller via Helm |
| `ecr.tf` | ECR repository |
| `outputs.tf` | Cluster name, endpoint, ECR URL, kubectl command |
| `k8s/deployment.yaml` | Kubernetes Deployment (2 replicas) |
| `k8s/service.yaml` | ClusterIP Service |
| `k8s/ingress.yaml` | Ingress — triggers ALB creation |
