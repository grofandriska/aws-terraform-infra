# AWS Terraform Infra – Cost-Optimized, Bastion-less Web Tier

A modular Terraform project that deploys a self-healing, auto-scaling web tier on AWS behind an Application Load Balancer. Instances are managed **without SSH, without key pairs and without a bastion host** – all shell access goes through **AWS Systems Manager Session Manager**, authenticated by IAM.

The main goal was to find a **cheaper and simpler alternative** to the classic *bastion host + NAT gateway* pattern, while keeping the instances locked down.

---

## Architecture

```
                    Internet
                       │
                       ▼  HTTP :80
          ┌─────────────────────────┐
          │ Application Load Balancer│  (lb_sg: 80 from 0.0.0.0/0)
          └────────────┬────────────┘
                       │  HTTP :80, only from lb_sg
        ┌──────────────┴──────────────┐
        ▼                             ▼
 ┌─────────────┐               ┌─────────────┐
 │  bandi-web  │               │  bandi-web  │   Auto Scaling Group
 │ eu-central-1a│              │ eu-central-1b│   (min 1, desired 2, max 3)
 └──────┬──────┘               └──────┬──────┘
        │  outbound HTTPS :443 (SSM agent)
        ▼
 AWS Systems Manager  ◄────  Engineer (aws ssm start-session, IAM auth)
```

There are no inbound rules for SSH. The SSM agent on each instance opens an **outbound** connection to the Systems Manager endpoint, and sessions are tunnelled through that connection.

---

## Features

- **Modular structure** – network, load balancer, IAM and compute are separate modules wired together through outputs and variables.
- **SSH-less access** – Session Manager with the `AmazonSSMManagedInstanceCore` policy; no port 22, no key pairs.
- **Least-privilege networking** – instances accept HTTP **only from the load balancer's security group**, so the ALB cannot be bypassed via the instance public IPs.
- **Self-healing** – the ASG uses **ELB health checks**: if the web server stops responding, the instance is replaced automatically.
- **Zero-touch rollouts** – the ASG references `latest_version` of the launch template and has an `instance_refresh` policy, so changing the user data and running `terraform apply` replaces instances one by one without downtime.
- **Auto scaling** – target tracking policy keeps average CPU around 50%.
- **Hardened instances** – IMDSv2 required; the web server runs as the unprivileged `www-data` user under systemd, with only the `CAP_NET_BIND_SERVICE` capability.
- **Shared-account friendly** – every resource is prefixed with `project_name` and tagged via provider `default_tags` (`Project`, `ManagedBy`), so resources are easy to identify and names don't collide with other users.
- **Input validation** – `project_name` is validated to stay within AWS naming limits.

---

## Design decisions

### SSM instead of a bastion host
| | Bastion + SSH | Session Manager |
|---|---|---|
| Extra EC2 instance | yes | no |
| Open inbound port | 22 | none |
| Key management | SSH keys to distribute and rotate | none, IAM only |
| Audit trail | manual | every session tied to an IAM identity |

### Public IP + strict security group instead of private subnets + NAT
The SSM agent needs outbound access to AWS. The textbook solution is private subnets with a NAT gateway (~38 USD/month in Frankfurt) or VPC interface endpoints. To keep the cost down, instances get a public IP, but their security group allows **no inbound traffic except HTTP from the load balancer**. This is a deliberate trade-off: a misconfigured security group rule would expose the instances directly, which cannot happen with private subnets (see *Roadmap*).

### Security group chaining instead of CIDR rules
The ALB has no fixed IP addresses – its nodes scale and change IPs. Referencing the ALB's security group in the instance security group always follows the real ALB nodes and blocks everything else.

---

## Repository structure

```
.
├── main.tf               # provider + module wiring
├── variables.tf          # region, project_name, instance_type, ami_id
├── output.tf             # website_url, vpc_id
├── versions.tf           # Terraform and AWS provider version constraints
├── terraform.tfvars
├── .gitignore
└── modules/
    ├── infra/            # VPC and subnet lookup
    ├── lb/               # ALB, target group, listener, ALB security group
    ├── iam-ssm/          # IAM role + instance profile for Session Manager
    └── asg/              # launch template, instance SG, ASG, scaling policy
        └── user_data.sh  # installs the web server as a systemd service
```

---

## Prerequisites

- Terraform >= 1.5
- AWS CLI v2 with credentials configured (`aws configure`)
- [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for the AWS CLI

---

## Usage

```bash
terraform init
terraform plan
terraform apply
```

After apply, Terraform prints the website URL:

```bash
curl $(terraform output -raw website_url)
# Hello from secure, modular SSM Terraform architecture!
```

Instances need 3–5 minutes to boot and pass the target group health checks.

### Connecting to an instance

```bash
aws ec2 describe-instances --region eu-central-1 \
  --filters "Name=tag:Name,Values=bandi-web" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" --output text

aws ssm start-session --region eu-central-1 --target <instance-id>
```

### Clean up

```bash
terraform destroy
```

---

## Verification

| Test | Command | Expected result |
|---|---|---|
| Website via ALB | `curl $(terraform output -raw website_url)` | page is returned |
| ALB bypass | `curl --max-time 10 http://<instance-public-ip>` | timeout |
| SSH | `ssh -o ConnectTimeout=10 ubuntu@<instance-public-ip>` | timeout |
| SSM access | `aws ssm start-session --target <id>` | shell opens |
| Non-root web server | `ps -o user,cmd -C python3` (on instance) | user is `www-data` |
| IMDSv2 enforced | `curl -s -o /dev/null -w "%{http_code}" http://169.254.169.254/latest/meta-data/` (on instance) | `401` |
| Self-healing | `sudo systemctl stop webserver` (on instance) | target becomes unhealthy, ASG replaces the instance, site stays up |
| Rolling update | change text in `user_data.sh`, `terraform apply` | instances replaced one by one, no downtime |

---

## Cost estimate (eu-central-1, approximate)

| Item | This project | Private subnets + NAT |
|---|---|---|
| 2 × t3.micro | ~17 USD/mo | ~17 USD/mo |
| Application Load Balancer | ~20 USD/mo | ~20 USD/mo |
| Public IPv4 addresses | ~15 USD/mo | ~11 USD/mo |
| NAT gateway | – | ~38 USD/mo + data |
| **Total** | **~50 USD/mo** | **~85 USD/mo** |

Prices are rounded and may change – check the [AWS Pricing Calculator](https://calculator.aws/). For short test sessions followed by `terraform destroy`, the cost is a few cents.

---

## Lessons learned: the NACL incident

After the first deployment, Session Manager showed every instance as *Not connected*, with this error from the agent:

```
dial tcp 3.78.206.74:443: i/o timeout
```

The IAM role, instance profile, security groups, route table, internet gateway and public IPs were all correct. Following the packet path layer by layer finally revealed the cause: the project runs in a **shared AWS account**, and the default VPC's **network ACL** had been modified by someone else to allow only inbound TCP 22 and outbound TCP 30000–65535. Since NACLs are **stateless**, both outbound HTTPS and its return traffic were blocked.

Takeaways:
- An `i/o timeout` points to the network path, not to permissions.
- Debug in layers: IP → route table → gateway → security group → NACL.
- Infrastructure code should own everything it depends on – relying on shared default resources means behaviour can change outside of your code.

The workaround was to add narrowly scoped NACL entries. The permanent fix is a dedicated VPC (see *Roadmap*).

---

## Known limitations

- Uses the account's **default VPC**, so it depends on the default network ACL configuration.
- HTTP only – HTTPS would require a domain and an ACM certificate.
- `python3 -m http.server` is a placeholder, not a production web server.
- Terraform state is stored locally.

## Roadmap

- [ ] Dedicated VPC with public and private subnets (ALB public, instances private, no instance public IPs)
- [ ] Remote state in S3 with locking
- [ ] HTTPS on the ALB with ACM
- [ ] CI pipeline: `terraform fmt -check`, `validate`, `tflint`, `checkov`
- [ ] Session Manager logging to S3 / CloudWatch
