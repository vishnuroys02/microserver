# Microservices CI/CD on AWS (Jenkins + Docker + Terraform + ECR + Prometheus/Grafana)

## Architecture
```
GitHub -> Jenkins (Amazon Linux) -> docker build/test -> Amazon ECR -> SSH deploy
                                                                  |
                                    EC2 Ubuntu: Docker Compose (Nginx + user/product/order) + Prometheus + Grafana
Terraform provisions: EC2, 3 ECR repos, Security Group, IAM role/instance profile
```

## Repo Structure
| Path | Purpose |
|------|---------|
| `user-service/ product-service/ order-service/` | Sample Node.js microservices + Dockerfiles |
| `nginx/nginx.conf` | Reverse proxy routing `/api/users`, `/api/products`, `/api/orders` |
| `docker-compose.yml` | Local build & run |
| `docker-compose.prod.yml` | EC2 deployment (images from ECR) |
| `docker-compose.monitoring.yml` | Prometheus, Node Exporter, cAdvisor, Blackbox, Grafana |
| `terraform/` | AWS infrastructure |
| `Jenkinsfile` | CI/CD pipeline |
| `scripts/` | deploy, verify, rollback, Jenkins server bootstrap |
| `docs/` | Deployment, rollback, troubleshooting notes |

## Prerequisites
- AWS account, region `ap-south-1`, budget alert configured
- Jenkins server (Amazon Linux) with Docker, AWS CLI, Terraform; IAM instance role with ECR PowerUser
- SSH key pair `~/.ssh/devops-key` (private key never committed)
- GitHub repo (private) with PAT stored in Jenkins credentials

## Branch Workflow
`feature/*` -> PR -> `dev` -> PR -> `main` (Jenkins builds and deploys from `main`).

## Quick Start
### 1. Run locally
```bash
export IMAGE_TAG=v1.0.0
docker compose up -d --build
curl localhost/api/orders/orders/connectivity
```
### 2. Provision AWS
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit IPs
terraform init && terraform validate
terraform plan -out=tfplan | tee plan-output.txt
terraform apply tfplan
```
### 3. Jenkins
Create credentials `github-pat`, `ec2-ssh-key`, `ec2-host`; create a Pipeline job from SCM (`Jenkinsfile`, branch `main`).

### 4. Access monitoring (not public)
```bash
ssh -i ~/.ssh/devops-key -L 3000:localhost:3000 -L 9090:localhost:9090 ubuntu@<APP_IP>
```
Grafana: http://localhost:3000 ; Prometheus: http://localhost:9090

## Cleanup
```bash
# on EC2
cd /opt/app && docker compose --env-file .env --env-file .deploy.env -f docker-compose.prod.yml -f docker-compose.monitoring.yml down -v
# on Jenkins server
cd terraform && terraform destroy
```
Then stop the Jenkins server and delete unused IAM access keys.

## More
See `docs/deployment.md`, `docs/rollback.md`, `docs/troubleshooting.md`.
