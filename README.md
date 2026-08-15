# Cert & Domain Expiry Checker

![Build and Deploy](https://github.com/JSamarxhi/cert-domain-checker/actions/workflows/deploy.yml/badge.svg)

**Live demo:** https://ca-cert-checker.purplesmoke-035a866a.eastus.azurecontainerapps.io/docs

A small FastAPI service that checks SSL certificate expiry and DNS status for a
list of domains. Containerized, deployed to Azure Container Apps with Terraform,
and released by a GitHub Actions pipeline.

I work in Microsoft cloud infrastructure day to day: identity and access,
endpoint management, migrations, and PowerShell automation. This project is
deliberate practice in the adjacent toolchain, built to take one service through
a complete pipeline rather than to read about it: Linux, containers,
infrastructure as code, and automated deployment.

## Stack

| Layer | Tool |
| --- | --- |
| Application | Python 3.12, FastAPI |
| Container | Docker |
| Registry | GitHub Container Registry |
| Infrastructure | Terraform, Azure Container Apps |
| CI/CD | GitHub Actions |

## API

| Method | Path | Description |
| --- | --- | --- |
| `GET` | `/health` | Liveness probe |
| `GET` | `/check?domain=example.com` | Check a single domain |
| `POST` | `/check` | Check a list of domains |
| `GET` | `/docs` | Interactive OpenAPI documentation |

```bash
curl -X POST https://ca-cert-checker.purplesmoke-035a866a.eastus.azurecontainerapps.io/check \
  -H "Content-Type: application/json" \
  -d '{"domains": ["example.com"]}'
```

```json
{
  "count": 1,
  "results": [
    {
      "domain": "example.com",
      "dns": { "resolves": true, "ips": ["93.184.215.14"], "error": null },
      "ssl": {
        "valid": true,
        "expires": "2026-03-01",
        "days_until_expiry": 223,
        "expired": false,
        "error": null
      }
    }
  ]
}
```

A failed lookup returns a structured error for that domain rather than failing the whole request. The certificate and DNS checks use only the standard library, so FastAPI is the sole runtime dependency.

## Running it

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Or with Docker:

```bash
docker build -t cert-checker .
docker run --rm -p 8000:8000 cert-checker
```

The image runs as a non-root user, and dependencies install in a separate layer from application code so editing source doesn't invalidate the dependency cache.

## Deployment

Pushing to `main` builds the image, pushes it to GitHub Container Registry,
and runs `terraform apply` against that image.

**No stored secrets.** GitHub authenticates to Azure using OpenID Connect.
Azure trusts short-lived tokens issued for this repository, so there is no
client secret in the repo or its settings.

**Deployments reference the commit SHA**, not `latest`, so a running revision
always maps to exactly one commit.

**The Container Apps environment is shared.** It lives in a separate resource
group and Terraform configuration; this project reads it rather than managing
it, so destroying this app can't affect anything else using it.

**Terraform state is in Azure Blob Storage**, shared between local runs and CI,
with blob leasing to prevent two applies running at once.

## Cost

The app scales to zero when idle and runs inside the Azure Container Apps monthly free grant. The only persistent cost is a few kilobytes of Terraform state in Blob Storage.

## Layout

```
.
├── app/
│   ├── main.py           # FastAPI routes and models
│   └── checker.py        # SSL expiry and DNS resolution
├── terraform/
│   └── main.tf           # resource group and container app
├── scripts/              # one-time OIDC federated identity setup
├── .github/workflows/
│   └── deploy.yml        # build, push, deploy
├── Dockerfile
├── requirements.txt
└── README.md
```

## Roadmap

- [x] FastAPI application with SSL and DNS checks
- [x] Containerized with Docker
- [x] Deployed to Azure Container Apps
- [x] Infrastructure defined in Terraform
- [x] Build and deploy automated via GitHub Actions
- [x] Passwordless CI authentication via OIDC federated identity
- [ ] Scheduled checks with alerting on approaching expiry
