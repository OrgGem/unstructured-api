# Building Docker Image with Pre-loaded Models

This guide explains how to build a Docker image of the Unstructured API with pre-loaded ML models (YOLO, PaddleOCR, Table Transformer) included in the image.

## Why Pre-load Models?

Pre-loading models in the Docker image provides several benefits:

1. **Faster Cold Starts**: No need to download models on first request
2. **Offline Operation**: Models available without internet connection
3. **Predictable Performance**: No network delays for model downloads
4. **Production Ready**: Consistent behavior across deployments
5. **Reduced Bandwidth**: Models included in image, no runtime downloads

## System Requirements

Building the image with preloaded models requires:

- **Disk Space**: Minimum 40GB free space (for build cache, models, and intermediate layers)
- **RAM**: At least 8GB RAM recommended
- **Docker**: Docker with buildx support enabled
- **Network**: Good internet connection for downloading dependencies and models (first time only)
- **Time**: 10-15 minutes for a complete build (depends on hardware and internet speed)

## Quick Start

### Option 1: Using the Provided Build Script (Recommended)

```bash
cd /path/to/unstructured-api
bash scripts/docker-build-with-models.sh
```

This script will:
- Check if you have sufficient disk space
- Build the Docker image with all models preloaded
- Tag the image appropriately
- Show you how to run and push the image

### Option 2: Manual Build

```bash
cd /path/to/unstructured-api
DOCKER_REPOSITORY="your-registry" \
PIPELINE_PACKAGE="general" \
docker buildx build --load -f Dockerfile \
  --build-arg PIPELINE_PACKAGE="general" \
  --progress plain \
  -t your-registry/unstructured-api:with-models \
  .
```

## Models Included

The pre-built image includes:

### 1. YOLO Detection Model (`yolox`)
- **Purpose**: Object detection for high-resolution document processing
- **Use Case**: Identifying layout elements and sections in documents
- **Size**: ~250MB
- **Environment Variable**: `HI_RES_MODEL_NAME=yolox`

### 2. PaddleOCR Models
- **Purpose**: Text extraction and OCR
- **Languages**: English (Spanish and other languages can be added)
- **Size**: ~500MB for English model
- **Auto-downloads**: Additional language models on first use if needed

### 3. Table Transformer Model
- **Model**: `microsoft/table-transformer-structure-recognition`
- **Purpose**: Table structure recognition and extraction
- **Size**: ~100MB
- **Framework**: HuggingFace Transformers

### 4. NLTK Data
- **Purpose**: Natural language processing utilities
- **Size**: ~100MB
- **Included**: Tokenizers and language patterns

## Build Process

The Dockerfile includes the following steps for model preloading:

1. **Base Setup**: Installs system dependencies (Tesseract, LibreOffice, Poppler)
2. **Python Environment**: Sets up Python 3.12 and project dependencies via `uv`
3. **NLTK Packages**: Downloads NLTK language data
4. **Unstructured Models**: Initializes general ML models
5. **Table Transformer**: Pre-loads Microsoft's table structure recognition model
6. **YOLO Model**: Pre-loads YOLO detection model
7. **PaddleOCR**: Pre-loads PaddleOCR English language model
8. **Application**: Copies application code and sets up entry point

## Build Output

After a successful build, you'll have an image with:

```
docker images | grep "unstructured-api"
```

The image size will be approximately **5-6GB** due to the included models and dependencies.

## Using the Pre-loaded Model Image

### Running Locally

```bash
docker run -p 8000:8000 your-registry/unstructured-api:with-models
```

### Using High-Resolution Strategy with YOLO

```bash
curl -X 'POST' \
  'http://localhost:8000/general/v0/general' \
  -H 'Content-Type: multipart/form-data' \
  -F 'files=@document.pdf' \
  -F 'strategy=hi_res' \
  -F 'hi_res_model_name=yolox'
```

### Using with Custom Root Path (Proxy Deployment)

```bash
docker run -p 8000:8000 \
  -e API_ROOT_PATH="/api/v1" \
  your-registry/unstructured-api:with-models
```

## Pushing to Registry

### Docker Hub

```bash
docker tag your-registry/unstructured-api:with-models username/unstructured-api:with-models
docker push username/unstructured-api:with-models
```

### Private Registry (e.g., Quay.io)

```bash
docker tag your-registry/unstructured-api:with-models quay.io/your-org/unstructured-api:with-models
docker login quay.io
docker push quay.io/your-org/unstructured-api:with-models
```

## Troubleshooting

### Build Fails: "No space left on device"

**Solution**: 
```bash
# Clean up Docker system
docker system prune -af --volumes

# Check available space
df -h /var/lib/docker

# Ensure at least 40GB free space
```

### Build Fails: Out of Memory

**Solution**:
```bash
# Increase Docker daemon memory limit
# Edit Docker daemon configuration or restart with more memory
# Typically set to 4GB+ in Docker Desktop settings
```

### Models Not Available in Container

**Solution**: Check that the build completed successfully:
```bash
# Test image
docker run --rm your-registry/unstructured-api:with-models \
  python -c "from paddleocr import PaddleOCR; print('Models loaded!')"
```

### Slow Build Speed

**Causes and Solutions**:
- Slow internet: Use a faster network or wait longer
- Slow disk: Use SSD storage for Docker
- Limited RAM: Allocate more memory to Docker daemon
- CPU: Slower CPUs take longer; wait or use faster hardware

## Build Time Estimates

Typical build times on modern hardware:

| Configuration | Time |
|---|---|
| On SSD with good internet | 10-15 minutes |
| On HDD with good internet | 20-30 minutes |
| On SSD with slow internet | 20-40 minutes |
| First build (no cache) | Add 5-10 minutes |

## Model Storage Locations in Container

Models are cached in standard locations within the container:

```
~/.cache/                          # YOLO and other models
~/.paddleocr/                      # PaddleOCR models  
~/.cache/huggingface/              # Table Transformer model
/usr/local/share/tessdata/         # Tesseract OCR data
```

## Environment Variables

Set these to customize model behavior:

```bash
# Use YOLO for high-resolution processing
HI_RES_MODEL_NAME=yolox

# Set number of OMP threads for parallel processing
OMP_NUM_THREADS=4

# Enable verbose logging during initialization
UNSTRUCTURED_LOG_LEVEL=DEBUG
```

## Advanced: Building Custom Model Variants

You can modify the Dockerfile to include additional languages or models:

### Adding More PaddleOCR Languages

Edit the PaddleOCR loading section in Dockerfile:

```dockerfile
RUN echo "Loading PaddleOCR models..." && \
    ${PYTHON} -c "
from paddleocr import PaddleOCR
import logging
logging.getLogger('ppocr').setLevel(logging.ERROR)
# Load multiple languages
for lang in ['en', 'es', 'fr', 'de']:
    ocr = PaddleOCR(lang=lang, show_log=False)
    print(f'PaddleOCR ({lang}) loaded')
"
```

### Adding Custom Models

Add additional model loading steps after the existing model preloading sections.

## CI/CD Integration

For automated builds in CI/CD:

```yaml
# GitHub Actions example
- name: Build Docker image with models
  run: |
    bash scripts/docker-build-with-models.sh
  env:
    DOCKER_REPOSITORY: ${{ secrets.REGISTRY }}/unstructured-api
    PIPELINE_PACKAGE: general
```

## Performance Comparison

### Without Pre-loaded Models
- First request: 30-60 seconds (includes model download)
- Subsequent requests: <2 seconds

### With Pre-loaded Models  
- First request: <2 seconds (models already loaded)
- Subsequent requests: <2 seconds
- **Improvement**: 15-30x faster first response

## Support and Issues

For build issues:

1. Check available disk space: `df -h /var/lib/docker`
2. Review build logs for specific error messages
3. Ensure Docker daemon has sufficient resources
4. Try building on a different machine with more resources
5. Check [GitHub Issues](https://github.com/Unstructured-IO/unstructured-api/issues) for known issues

## See Also

- [PROXY_DEPLOYMENT.md](./PROXY_DEPLOYMENT.md) - Proxy deployment configuration
- [README.md](./README.md) - General API documentation
- [docker-build-with-models.sh](./scripts/docker-build-with-models.sh) - Build script
