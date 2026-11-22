"""Opt-in fault injection endpoint used by chaos experiments."""

from fastapi import APIRouter, HTTPException, Response, status

from config import settings

router = APIRouter()


@router.post("/chaos/fail", tags=["chaos"])
def fail(response: Response) -> dict[str, str]:
    """Return HTTP 503 on demand when fault injection is enabled.

    The endpoint is intentionally inert by default. Deployment overlays set
    FAULT_INJECTION_ENABLED=true only for dev and staging; prod never does.
    Chaos tooling can call this endpoint to exercise rollback and alerting.
    """
    if not settings.fault_injection_enabled:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="not found")
    response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return {"status": "injected_failure"}
