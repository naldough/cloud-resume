# Cloud Resume Challenge — Ronaldo Pardieu

Live site: [ronaldoauguste.com](https://ronaldoauguste.com)

A personal portfolio and resume site built as part of the [Cloud Resume Challenge](https://cloudresumechallenge.dev/), designed to demonstrate practical AWS and DevOps skills beyond certifications.

---

## Architecture

```
Browser
  │
  ├── HTTPS → CloudFront (CDN, WAF, security headers)
  │              │
  │              └── S3 (private, OAC-only static hosting)
  │
  └── HTTPS → api.ronaldoauguste.com
                 │
                 └── API Gateway (HTTP API, throttled)
                        │
                        └── Lambda (Python 3.13)
                               ├── Secrets Manager (Anthropic API key)
                               ├── DynamoDB (per-IP rate limiting)
                               └── Anthropic API (Claude, resume Q&A)

DNS: Route 53 (A/AAAA aliases for apex, www, and api subdomains)
TLS: ACM certificates (us-east-1 for CloudFront, us-east-2 for API Gateway)
IaC: Terraform with remote state in S3 + DynamoDB locking
CI/CD: GitHub Actions (syncs site/ to S3 on push to main)
```

---

## Repository structure

```
.
├── assistant/              # AI resume assistant Lambda
│   ├── handler.py          # Lambda handler — calls Anthropic API
│   └── knowledge.json      # Grounding data (resume, projects, certs)
│
├── infra/
│   ├── bootstrap/          # One-time setup: S3 state bucket + DynamoDB lock table
│   └── envs/prod/          # Main infrastructure
│       ├── main.tf         # S3, CloudFront, ACM, Route 53
│       ├── assistant.tf    # Lambda, API Gateway, DynamoDB, Secrets Manager
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── backend.tf
│
├── site/                   # Static frontend (deployed to S3 via GitHub Actions)
│   ├── index.html
│   ├── cloudresume.html
│   ├── covidreporting.html
│   ├── devopslab.html
│   ├── porcupine.html
│   └── assets/
│       ├── css/assistant.css   # Chat widget styles
│       └── js/assistant.js     # Chat widget logic
│
└── .github/workflows/
    └── cicd.yml            # Deploys site/ to S3 on push to main
```

---

## AI resume assistant

A floating "Ask Ronaldo" chat widget on every page lets visitors ask natural-language questions about my experience, projects, certifications, and the Cloud Resume Challenge.

**How it works:**
1. Widget POSTs `{ message }` to `https://api.ronaldoauguste.com/chat`
2. Lambda reads the Anthropic API key from Secrets Manager (cached in memory)
3. Lambda sends the question to Claude with a system prompt grounded on `knowledge.json` — only facts about Ronaldo, no outside knowledge
4. Response is returned and rendered in the widget

**Abuse protection:**
- API Gateway stage throttling (5 req/s rate, 10 burst)
- DynamoDB fixed-window per-IP rate limit (8 req/hour by default) inside the Lambda
- CORS locked to `ronaldoauguste.com` origins only

---

## Deploying

### Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform >= 1.5
- An Anthropic API key from [console.anthropic.com](https://console.anthropic.com)

### First-time bootstrap (state bucket + lock table)

```bash
cd infra/bootstrap
terraform init
terraform apply
```

### Main infrastructure

```bash
cd infra/envs/prod
terraform init
terraform apply
```

After apply, set the Anthropic API key (value is never stored in Terraform state or git):

```bash
aws secretsmanager put-secret-value \
  --secret-id cloud-resume/anthropic-api-key \
  --secret-string "sk-ant-..." \
  --region us-east-2
```

> **Set a spend limit** on the Anthropic console under Billing → Limits. AWS Budgets won't track Anthropic charges.

### Frontend

GitHub Actions deploys automatically on push to `main`. To deploy manually:

```bash
aws s3 sync site/ s3://ronaldo-auguste-resume --delete --region us-east-2
aws cloudfront create-invalidation --distribution-id <ID> --paths "/*"
```

---

## IAM permissions required

The `Cloud-resume` IAM user needs the following AWS managed policies to run `terraform apply`:

| Policy | Purpose |
|---|---|
| `AWSLambda_FullAccess` | Lambda function |
| `IAMFullAccess` | Lambda execution role |
| `SecretsManagerReadWrite` | API key secret |
| `AmazonAPIGatewayAdministrator` | HTTP API + custom domain |
| `CloudWatchLogsFullAccess` | Log groups |
| `AmazonDynamoDBFullAccess` | Rate-limit table |
| `AWSCertificateManagerFullAccess` | ACM cert for api subdomain |

---

## Stack

| Layer | Technology |
|---|---|
| Hosting | AWS S3 + CloudFront |
| DNS | AWS Route 53 |
| TLS | AWS ACM |
| CDN security | AWS WAF (CloudFront-managed) |
| AI backend | AWS Lambda (Python 3.13) + Anthropic Claude |
| API | AWS API Gateway HTTP API |
| Rate limiting | AWS DynamoDB |
| Secrets | AWS Secrets Manager |
| IaC | Terraform |
| CI/CD | GitHub Actions |
