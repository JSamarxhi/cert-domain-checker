# Cert & Domain Expiry Checker

A small FastAPI service that reports **SSL certificate expiry** and **DNS status**
for a list of domains. Deliberately simple app; the point is the DevOps wrapper
around it (Docker, Terraform, GitHub Actions).

Developed on **WSL2 / Ubuntu** — same Linux userland the container and the
GitHub Actions runner use. See `SETUP-WSL.md` for toolchain install.

## Build slices
1. **Local app** (this) — FastAPI running in WSL.
2. **Docker** — package the app into a container.
3. **Manual Azure deploy** — push the image and run it once via the portal.
4. **Terraform** — rewrite that deploy as infrastructure-as-code.
5. **GitHub Actions** — a push builds the image and deploys it.

## Slice 1 — run locally (Ubuntu / WSL)
```bash
cd ~/projects/cert-domain-checker
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```
Then open http://127.0.0.1:8000/docs in your Windows browser — WSL forwards
localhost automatically. Or:
- http://127.0.0.1:8000/health
- http://127.0.0.1:8000/check?domain=example.com

POST multiple domains:
```bash
curl -X POST http://127.0.0.1:8000/check \
  -H "Content-Type: application/json" \
  -d '{"domains": ["example.com", "github.com"]}'
```

## Slice 2 — run in Docker
```bash
docker build -t cert-checker .
docker run --rm -p 8000:8000 cert-checker
```
Same URLs as above. If it works in the container, slice 2 is done.

## Endpoints
| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Liveness probe |
| GET | `/check?domain=...` | Check one domain |
| POST | `/check` | Check a list of domains (JSON body) |
