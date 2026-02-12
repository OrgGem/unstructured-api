# Proxy Deployment and Model Preloading Configuration

## Proxy Deployment with Custom Subpath

The Unstructured API now supports deployment behind a reverse proxy (like Nginx) with a custom subpath configuration.

### Configuration

Set the `API_ROOT_PATH` environment variable to specify the subpath where the API will be served:

```bash
export API_ROOT_PATH="/api/v1"
```

### Example Nginx Configuration

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location /api/v1/ {
        proxy_pass http://localhost:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Docker Deployment

When running the Docker container with a custom subpath:

```bash
docker run -p 8000:8000 -e API_ROOT_PATH="/api/v1" \
  downloads.unstructured.io/unstructured-io/unstructured-api:latest
```

### Accessing the API

With `API_ROOT_PATH="/api/v1"`, the endpoints will be:

- Health check: `http://your-domain.com/api/v1/healthcheck`
- Main endpoint: `http://your-domain.com/api/v1/general/v0/general`
- API docs: `http://your-domain.com/api/v1/general/docs`

### Local Development

For local development with a custom subpath:

```bash
export API_ROOT_PATH="/api/v1"
make run-web-app
```

Or directly:

```bash
API_ROOT_PATH="/api/v1" uvicorn prepline_general.api.app:app \
  --host 0.0.0.0 --port 8000 --root-path /api/v1
```

## Pre-loaded Models in Docker Image

The Docker image now includes pre-loaded OCR and detection models to improve cold-start performance:

### Included Models

1. **YOLO Detection Model** (`yolox`)
   - Used for object detection in high-resolution document processing
   - Model is downloaded and cached during Docker build
   - Available for `hi_res` strategy with `hi_res_model_name=yolox`

2. **PaddleOCR Models**
   - Pre-loaded OCR models for text extraction
   - Supports multiple languages
   - Cached during Docker build for offline use

3. **Table Transformer Model**
   - Microsoft table structure recognition model
   - Pre-loaded for table extraction features

### Benefits

- **Faster cold starts**: No model download on first request
- **Offline capability**: Models available without internet access
- **Predictable performance**: No network delays for model downloads
- **Production-ready**: Consistent behavior across deployments

### Usage Example with YOLO

```bash
curl -X 'POST' \
  'http://localhost:8000/general/v0/general' \
  -H 'Content-Type: multipart/form-data' \
  -F 'files=@document.pdf' \
  -F 'strategy=hi_res' \
  -F 'hi_res_model_name=yolox'
```

### Model Storage

Models are cached in the user's home directory within the container:
- YOLO models: `~/.cache/`
- PaddleOCR models: `~/.paddleocr/`
- Table models: `~/.cache/huggingface/`

### Build Time Impact

The model pre-loading adds approximately 2-5 minutes to the Docker build time and increases the image size by ~1-2GB, but this is offset by:
- Faster application startup
- No runtime model downloads
- Better user experience
- Reduced network dependency

## Environment Variables Reference

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `API_ROOT_PATH` | Subpath for proxy deployment | `""` (root) | `/api/v1` |
| `PORT` | Server port | `8000` | `8080` |
| `HOST` | Server host | `0.0.0.0` | `127.0.0.1` |
| `WORKERS` | Number of workers | `1` | `4` |
| `MAX_LIFETIME_SECONDS` | Server lifetime | none | `3600` |

## Testing the Configuration

### Test Root Path Configuration

```python
import os
os.environ["API_ROOT_PATH"] = "/api/v1"

from prepline_general.api.app import app
print(f"Root path: {app.root_path}")  # Should print: /api/v1
```

### Test Health Check

```bash
# Without root path
curl http://localhost:8000/healthcheck

# With root path /api/v1
curl http://localhost:8000/api/v1/healthcheck
```

### Test Main Endpoint

```bash
# Without root path
curl -X POST http://localhost:8000/general/v0/general \
  -F 'files=@test.txt'

# With root path /api/v1
curl -X POST http://localhost:8000/api/v1/general/v0/general \
  -F 'files=@test.txt'
```

## Troubleshooting

### Issue: API returns 404 Not Found

**Cause**: Mismatch between `API_ROOT_PATH` and request URL

**Solution**: Ensure the request URL includes the root path:
- If `API_ROOT_PATH="/api"`, use `http://host:port/api/general/...`
- If `API_ROOT_PATH=""`, use `http://host:port/general/...`

### Issue: Models not found at runtime

**Cause**: Docker image built without model pre-loading

**Solution**: Rebuild the Docker image with the latest Dockerfile that includes model initialization

### Issue: Nginx returns 502 Bad Gateway

**Cause**: Proxy configuration doesn't match API root path

**Solution**: Update Nginx configuration to match the `API_ROOT_PATH`:
```nginx
location /api/v1/ {
    proxy_pass http://backend:8000/;  # Note trailing slash
}
```
