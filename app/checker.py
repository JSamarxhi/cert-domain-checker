"""Core checks: SSL certificate expiry and DNS resolution.

Uses only the Python standard library (ssl, socket) so the container stays
small and dependency-free for the checking logic itself.
"""

from __future__ import annotations

import socket
import ssl
from datetime import datetime, timezone


# TLS cert timestamps look like: 'Jun  1 12:00:00 2026 GMT'
_CERT_TIME_FMT = "%b %d %H:%M:%S %Y %Z"


def check_dns(domain: str, timeout: float = 5.0) -> dict:
    """Resolve a domain to its A/AAAA records.

    Returns a dict with the resolved IPs, or an error string if it fails.
    """
    try:
        socket.setdefaulttimeout(timeout)
        # getaddrinfo returns both IPv4 and IPv6; dedupe the addresses.
        infos = socket.getaddrinfo(domain, None)
        ips = sorted({info[4][0] for info in infos})
        return {"resolves": True, "ips": ips, "error": None}
    except socket.gaierror as e:
        return {"resolves": False, "ips": [], "error": f"DNS lookup failed: {e}"}
    except Exception as e:  # noqa: BLE001 - report anything unexpected, don't crash the request
        return {"resolves": False, "ips": [], "error": str(e)}


def check_ssl(domain: str, port: int = 443, timeout: float = 5.0) -> dict:
    """Open a TLS connection and read the certificate's expiry date.

    Returns days-until-expiry and the not-after date, or an error string.
    """
    context = ssl.create_default_context()
    try:
        with socket.create_connection((domain, port), timeout=timeout) as sock:
            with context.wrap_socket(sock, server_hostname=domain) as ssock:
                cert = ssock.getpeercert()

        not_after_raw = cert.get("notAfter")
        if not not_after_raw:
            return {"valid": False, "error": "Certificate had no notAfter field"}

        # Parse the cert expiry and mark it as UTC.
        not_after = datetime.strptime(not_after_raw, _CERT_TIME_FMT).replace(
            tzinfo=timezone.utc
        )
        days_left = (not_after - datetime.now(timezone.utc)).days

        return {
            "valid": True,
            "expires": not_after.date().isoformat(),
            "days_until_expiry": days_left,
            "expired": days_left < 0,
            "error": None,
        }
    except ssl.SSLCertVerificationError as e:
        return {"valid": False, "error": f"Certificate verification failed: {e}"}
    except (socket.timeout, TimeoutError):
        return {"valid": False, "error": "Connection timed out"}
    except ConnectionRefusedError:
        return {"valid": False, "error": f"Connection refused on port {port}"}
    except socket.gaierror as e:
        return {"valid": False, "error": f"DNS lookup failed: {e}"}
    except Exception as e:  # noqa: BLE001
        return {"valid": False, "error": str(e)}


def check_domain(domain: str) -> dict:
    """Run both checks for a single domain and combine the results."""
    domain = domain.strip().lower()
    return {
        "domain": domain,
        "dns": check_dns(domain),
        "ssl": check_ssl(domain),
    }
