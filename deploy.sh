#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

IMAGE_NAME="devops-evaluation-app"
CONTAINER_NAME="devops-app-prod"
HOST_PORT=8080
CONTAINER_PORT=3000
NODE_ENV="production"
APP_PORT=3000

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

cleanup() {
    print_status "Cleaning up..."
    docker stop $CONTAINER_NAME 2>/dev/null
    docker rm $CONTAINER_NAME 2>/dev/null
}

trap 'if [ $? -ne 0 ]; then cleanup; fi' EXIT


print_status "Checking Docker installation..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start the Docker service."
    exit 1
fi

print_success "Docker is installed and running correctly."

    print_status "Checking for existing container..."
    if docker ps -a --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        print_warning "Contenedor $CONTAINER_NAME ya existe. Deteniendo y eliminando..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

print_status "Building Docker image..."
if docker build -t $IMAGE_NAME .; then
    print_success "Image built successfully: $IMAGE_NAME"
else
    print_error "Error al construir la imagen Docker."
    exit 1
fi

print_status "Running container with environment variables..."
print_status "Environment variables: PORT=$APP_PORT, NODE_ENV=$NODE_ENV"

if docker run -d \
    --name $CONTAINER_NAME \
    -p $HOST_PORT:$CONTAINER_PORT \
    -e PORT=$APP_PORT \
    -e NODE_ENV=$NODE_ENV \
    $IMAGE_NAME; then
    
    print_success "Container running: $CONTAINER_NAME"
else
    print_error "Error running container."
    exit 1
fi

print_status "A little bit of patience for application to be ready... pls wait 5 seconds"
sleep 5

print_status "Testing connectivity..."

if ! docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    print_error "Container is not running correctly."
    exit 1
fi

print_status "Testing main endpoint..."
if curl -f -s http://localhost:$HOST_PORT > /dev/null; then
    print_success "Main endpoint is responding correctly"
else
    print_error "Main endpoint is not responding"
    exit 1
fi

print_status "Testing health endpoint..."
if curl -f -s http://localhost:$HOST_PORT/health > /dev/null; then
    print_success "Health endpoint is responding correctly"
else
    print_error "Health endpoint is not responding"
    exit 1
fi

print_status "Getting application information..."
RESPONSE=$(curl -s http://localhost:$HOST_PORT)
echo "Application response:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

echo ""
echo "  DEPLOY SUMMARY"
print_success "Deployment completed successfully!"
echo ""
echo "Deployment details:"
echo "   • Imagen: $IMAGE_NAME"
echo "   • Container: $CONTAINER_NAME"
echo "   • Host port: $HOST_PORT"
echo "   • Container port: $CONTAINER_PORT"
echo "   • Environment: $NODE_ENV"
echo "   • Access URL: http://localhost:$HOST_PORT"
echo "   • Health check: http://localhost:$HOST_PORT/health"
echo ""
echo "Useful commands:"
echo "   • View logs: docker logs $CONTAINER_NAME"
echo "   • Stop: docker stop $CONTAINER_NAME"
echo "   • Delete: docker rm $CONTAINER_NAME"
echo "   • Status: docker ps | grep $CONTAINER_NAME"
echo ""

if docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    print_success "Final state: Container running correctly"
    exit 0
else
    print_error "Final state: Error - Container not running"
    exit 1
fi 