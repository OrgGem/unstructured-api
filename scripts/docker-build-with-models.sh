#!/usr/bin/env bash

# Build script for Docker image with pre-loaded models
# This script builds the Unstructured API Docker image with YOLO, PaddleOCR, 
# and Table Transformer models pre-loaded for faster cold starts
#
# Requirements:
#   - At least 40GB free disk space (for Docker build, models, and caches)
#   - Docker with buildx support
#   - At least 8GB RAM recommended
#
# Usage:
#   bash scripts/docker-build-with-models.sh
#   
# With custom options:
#   DOCKER_REPOSITORY=my-registry PIPELINE_PACKAGE=general bash scripts/docker-build-with-models.sh

set -euo pipefail

# Configuration
DOCKER_REPOSITORY="${DOCKER_REPOSITORY:-quay.io/unstructured-io/unstructured-api}"
PIPELINE_PACKAGE="${PIPELINE_PACKAGE:-general}"
PIPELINE_FAMILY="${PIPELINE_FAMILY:-general}"
DOCKER_IMAGE="${DOCKER_IMAGE:-pipeline-family-${PIPELINE_FAMILY}-with-models}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
BUILD_TAG="${BUILD_TAG:-latest}"

echo "=============================================="
echo "Unstructured API Docker Build with Models"
echo "=============================================="
echo ""
echo "Configuration:"
echo "  Repository: $DOCKER_REPOSITORY"
echo "  Image name: $DOCKER_IMAGE"
echo "  Package: $PIPELINE_PACKAGE"
echo "  Platform: $DOCKER_PLATFORM"
echo "  Tag: $BUILD_TAG"
echo ""

# Check disk space
echo "Checking disk space requirements..."
AVAILABLE_SPACE=$(df /var/lib/docker 2>/dev/null | awk 'NR==2 {print $4}' || df /var | awk 'NR==2 {print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

echo "  Available disk space: ${AVAILABLE_GB}GB"
if [ "$AVAILABLE_GB" -lt 40 ]; then
    echo ""
    echo "⚠️  WARNING: This build requires at least 40GB free disk space"
    echo "   Current available: ${AVAILABLE_GB}GB"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Building Docker image with preloaded models..."
echo ""

DOCKER_BUILD_CMD=(
    docker buildx build --load -f Dockerfile
    --build-arg BUILDKIT_INLINE_CACHE=1
    --build-arg PIPELINE_PACKAGE="$PIPELINE_PACKAGE"
    --progress plain
    --platform "$DOCKER_PLATFORM"
    --cache-from "$DOCKER_REPOSITORY:$BUILD_TAG"
    -t "$DOCKER_IMAGE:$BUILD_TAG"
    .
)

DOCKER_BUILDKIT=1 "${DOCKER_BUILD_CMD[@]}"

BUILD_EXIT_CODE=$?

echo ""
echo "=============================================="
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "Image created: $DOCKER_IMAGE:$BUILD_TAG"
    echo ""
    echo "Models pre-loaded in this image:"
    echo "  - YOLO Detection Model (yolox)"
    echo "  - PaddleOCR Models (English)"  
    echo "  - Table Transformer Model (microsoft/table-transformer-structure-recognition)"
    echo "  - NLTK Packages"
    echo ""
    echo "To run the image:"
    echo "  docker run -p 8000:8000 $DOCKER_IMAGE:$BUILD_TAG"
    echo ""
    echo "To tag and push to registry:"
    echo "  docker tag $DOCKER_IMAGE:$BUILD_TAG $DOCKER_REPOSITORY:$BUILD_TAG"
    echo "  docker push $DOCKER_REPOSITORY:$BUILD_TAG"
else
    echo "❌ Build failed with exit code: $BUILD_EXIT_CODE"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Ensure you have at least 40GB free disk space"
    echo "  2. Try running 'docker system prune -a' to free up space"
    echo "  3. Check Docker daemon resources (RAM, CPU)"
    echo "  4. Review build output above for specific errors"
fi
echo "=============================================="

exit $BUILD_EXIT_CODE
