#!/bin/bash

set -e

echo "Building Meowcoin Dashboard..."

# Build shared package
echo "Building shared package..."
cd shared
npm install
npm run build
cd ..

# Build backend
echo "Building backend..."
cd backend
npm install
npm run build
cd ..

# Build frontend
echo "Building frontend..."
cd frontend
npm install
npm run build
cd ..

echo "Build complete!"