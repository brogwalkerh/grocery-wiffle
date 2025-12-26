#!/bin/bash

# GroceryCompare Production Deployment Script
# Run this on your Mac Mini server

set -e

echo "🛒 GroceryCompare Production Deployment"
echo "======================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker Desktop first."
    echo "   https://docs.docker.com/desktop/install/mac-install/"
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not available."
    exit 1
fi

# Check for .env file
if [ ! -f .env ]; then
    echo "⚠️  No .env file found. Creating from example..."
    cp .env.example .env
    echo "📝 Please edit .env with your actual values:"
    echo "   - POSTGRES_PASSWORD (required)"
    echo "   - DOMAIN (your dynamic DNS hostname)"
    echo "   - KROGER_CLIENT_ID (optional)"
    echo "   - KROGER_CLIENT_SECRET (optional)"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Load environment variables
source .env

# Validate required variables
if [ -z "$POSTGRES_PASSWORD" ] || [ "$POSTGRES_PASSWORD" = "your_secure_password_here" ]; then
    echo "❌ Please set POSTGRES_PASSWORD in .env"
    exit 1
fi

echo "🔨 Building and starting containers..."

# Use docker compose (v2) or docker-compose (v1)
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# Build and start in production mode
$COMPOSE_CMD -f docker-compose.prod.yml build
$COMPOSE_CMD -f docker-compose.prod.yml up -d

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Status:"
$COMPOSE_CMD -f docker-compose.prod.yml ps

echo ""
echo "🔗 Access points:"
echo "   - API: http://localhost:8000"
echo "   - Docs: http://localhost:8000/docs"
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "grocery.yourdomain.com" ]; then
    echo "   - Production: https://$DOMAIN"
fi

echo ""
echo "📝 Useful commands:"
echo "   View logs:      $COMPOSE_CMD -f docker-compose.prod.yml logs -f"
echo "   Stop:           $COMPOSE_CMD -f docker-compose.prod.yml down"
echo "   Restart:        $COMPOSE_CMD -f docker-compose.prod.yml restart"
echo "   Update & deploy: git pull && ./deploy.sh"
