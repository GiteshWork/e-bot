
# Stage 1: Build
FROM python:3.12.12-slim-bookworm AS builder

WORKDIR /build

# Create an isolated Python environment
RUN python -m venv /opt/venv

# Install application dependencies
COPY requirements.txt .
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt


# Stage 2: Runtime
FROM python:3.12.12-slim-bookworm AS runtime

WORKDIR /app

# Create a non-root user
RUN groupadd --system appgroup && \
    useradd --system --gid appgroup --no-create-home appuser

# Copy Python environment from builder
COPY --from=builder /opt/venv /opt/venv

# Copy application source
COPY app.py .

# Use virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# Application port
EXPOSE 8080

# Run as non-root user
USER appuser

CMD ["python", "-u", "app.py"]
