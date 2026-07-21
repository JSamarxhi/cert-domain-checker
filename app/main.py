"""FastAPI entrypoint for the certificate & domain expiry checker.

Endpoints:
  GET  /health              -> liveness probe (used later by Azure/monitoring)
  POST /check               -> body: {"domains": ["example.com", ...]}
  GET  /check?domain=...    -> quick single-domain check from the browser
"""

from __future__ import annotations

from fastapi import FastAPI
from pydantic import BaseModel, Field

from .checker import check_domain

app = FastAPI(
    title="Cert & Domain Expiry Checker",
    description="Reports SSL certificate expiry and DNS status for a list of domains.",
    version="0.1.0",
)


class CheckRequest(BaseModel):
    domains: list[str] = Field(..., min_length=1, examples=[["example.com", "github.com"]])


@app.get("/health")
def health() -> dict:
    """Simple liveness check."""
    return {"status": "ok"}


@app.get("/check")
def check_single(domain: str) -> dict:
    """Check one domain via query string, e.g. /check?domain=example.com."""
    return check_domain(domain)


@app.post("/check")
def check_many(req: CheckRequest) -> dict:
    """Check a list of domains posted as JSON."""
    results = [check_domain(d) for d in req.domains]
    return {"count": len(results), "results": results}
