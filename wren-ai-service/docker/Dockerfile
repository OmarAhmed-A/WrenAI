# reference: https://medium.com/@albertazzir/blazing-fast-python-docker-builds-with-poetry-a78a66f5aed0
FROM python:3.12.0-bookworm as builder

RUN pip install poetry==1.8.3

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    POETRY_CACHE_DIR=/tmp/poetry_cache

WORKDIR /app

COPY pyproject.toml ./

RUN poetry install --without dev,eval,test --no-root && rm -rf $POETRY_CACHE_DIR

FROM python:3.12.0-slim-bookworm as runtime

# If your entrypoint needs bash, install it; otherwise you can drop 'bash'
RUN apt-get update && apt-get install -y --no-install-recommends netcat-traditional bash \
    && rm -rf /var/lib/apt/lists/*

ENV VIRTUAL_ENV=/app/.venv \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

COPY --from=builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}

COPY src ./src
COPY entrypoint.sh ./entrypoint.sh
COPY pyproject.toml ./pyproject.toml

# Normalize Windows CRLF to LF and make executable
RUN sed -i 's/\r$//' /app/entrypoint.sh && chmod +x /app/entrypoint.sh

ENTRYPOINT [ "/app/entrypoint.sh" ]