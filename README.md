# Cert & Domain Expiry Checker

![Build and Deploy](https://github.com/JSamarxhi/cert-domain-checker/actions/workflows/deploy.yml/badge.svg)

An HTTP service that reports **SSL/TLS certificate expiry** and **DNS resolution
status** for a list of domains, deployed to Azure Container Apps from a fully
automated pipeline.

**Live demo:** https://ca-cert-checker.yellowsmoke-5b4ceb7b.eastus.azurecontainerapps.io/docs

Expired certificates are a recurring and entirely preventable cause of outages.
They fail silently until the moment they take a site down. This service exposes
that data over a simple API so it can be polled, alerted on, or dropped into a
dashboard.

## About this project

I work in Microsoft cloud infrastructure day to day: identity and access,
endpoint management, migrations, and PowerShell automation. This project is
deliberate practice in the adjacent toolchain, built to take one service through
a complete pipeline rather than to read about it: Linux, containers,
infrastructure as code, and automated deployment.

The application itself is small on purpose. The domain is one I have worked in
directly, having rolled out Let's Encrypt certificates and uptime monitoring
across 60+ client sites in a previous role, so the effort goes into the delivery
pipeline instead of inventing a problem to solve.

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

**Example**

```bash
curl -X POST https://ca-cert-checker.yellowsmoke-5b4ceb7b.eastus.azurecontainerapps.io/check \
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

The certificate and DNS checks use only the Python standard library (`ssl` and
`socket`), so the runtime dependency surface is limited to the web framework.
Failed lookups return a structured error for that domain rather than failing the
whole request.

## Running locally

Requires Python 3.12+.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Then open http://127.0.0.1:8000/docs

## Running with Docker

```bash
docker build -t cert-checker .
docker run --rm -p 8000:8000 cert-checker
```

The image runs as a non-root user, and dependencies install in a separate layer
from the application code so that editing source does not invalidate the
dependency cache on rebuild.

## Deployment

Pushing to `main` triggers a GitHub Actions workflow that builds the image,
pushes it to GitHub Container Registry, and applies the Terraform configuration
in `terraform/` against that specific image.

Three decisions worth calling out:

**No stored credentials.** GitHub authenticates to Azure using OpenID Connect
workload identity federation. GitHub issues a short-lived token describing the
workflow run, and Entra ID is configured to trust that issuer for this
repository and branch specifically, using immutable repository identifiers so
the trust survives a rename and cannot be inherited by a re-registered
username. No client secret exists in the repository or in repository settings.

**Immutable image tags.** Deployments reference the commit SHA rather than
`latest`, so any running revision maps to exactly one commit.

**Remote state.** Terraform state lives in Azure Blob Storage so local runs and
CI runs share the same state, with blob leasing providing lock safety. The
storage account is created outside Terraform, since state cannot manage the
location of its own storage.

### One-time setup

```bash
./scripts/bootstrap-state.sh                     # create the state storage account
./scripts/setup-oidc.sh <owner>/<repo>           # create the federated identity
```

Then fill the printed values into `terraform/backend.tf` and set the three
repository secrets the second script prints.

### Cost

The application scales to zero when idle and runs inside the Azure Container
Apps monthly free grant. The only persistent resource with a nonzero cost is the
few kilobytes of Terraform state in Blob Storage. Environments can be recreated
or torn down entirely with `terraform apply` and `terraform destroy`.

## Project layout

```
.
├── app/
│   ├── main.py           # FastAPI routes and request/response models
│   └── checker.py        # SSL expiry and DNS resolution logic
├── terraform/            # Azure infrastructure as code
│   ├── main.tf           # resource group, log analytics, container app
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf       # provider and version pinning
│   └── backend.tf        # remote state configuration
├── scripts/              # one-time bootstrap for state and OIDC
├── .github/
│   └── workflows/
│       └── deploy.yml    # build, push, and deploy pipeline
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
