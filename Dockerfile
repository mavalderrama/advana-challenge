FROM ghcr.io/astral-sh/uv:python3.14-bookworm-slim AS deps

WORKDIR /app

ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc g++ build-essential && \
    rm -rf /var/lib/apt/lists/*

COPY pyproject.toml uv.lock ./

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

FROM python:3.14-slim AS runtime

WORKDIR /app

RUN useradd --create-home --shell /bin/bash appuser

COPY --from=deps /app/.venv /app/.venv

COPY --chown=appuser:appuser challenge/ ./challenge/
COPY --chown=appuser:appuser artifacts/ ./artifacts/

RUN chown -R appuser:appuser /app

USER appuser

ENV PATH="/app/.venv/bin:$PATH"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

ENV PORT=8080
EXPOSE 8080

CMD exec uvicorn challenge.api:app --host 0.0.0.0 --port ${PORT}
