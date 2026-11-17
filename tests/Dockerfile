FROM ghcr.io/astral-sh/uv:0.13.7 AS uv
FROM python:3.12-slim
COPY --from=uv /uv /bin/uv
RUN apt-get update && apt-get install -y --no-install-recommends restic sqlite3 util-linux \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /work
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-install-project
COPY ansible/bootstrap.yml ./ansible/bootstrap.yml
COPY scripts ./scripts
COPY tests ./tests
CMD ["uv", "run", "--locked", "python", "-m", "unittest", "discover", "-s", "tests", "-v"]
