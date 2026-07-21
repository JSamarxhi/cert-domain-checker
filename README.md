# Cert & Domain Expiry Checker

A small HTTP service that reports **SSL/TLS certificate expiry** and **DNS
resolution status** for a list of domains.

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
| Infrastructure | Terraform, Azure |
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
curl -X POST http://localhost:8000/check \
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
Failed lookups return a structured error per domain rather than failing the
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

## Project layout

```
.
├── app/
│   ├── main.py       # FastAPI routes and request/response models
│   └── checker.py    # SSL expiry and DNS resolution logic
├── Dockerfile
├── requirements.txt
└── README.md
```

## Roadmap

- [x] FastAPI application with SSL and DNS checks
- [x] Containerized with Docker
- [ ] Deployed to Azure Container Apps
- [ ] Infrastructure defined in Terraform, with environments created and
      destroyed from code each session
- [ ] Build and deploy automated via GitHub Actions
- [ ] Scheduled checks with alerting on approaching expiry
