#!/bin/bash

# SonarQube Local Analysis Script for IEAD Project
# This script runs SonarQube analysis locally using SonarScanner CLI

echo "🔍 Starting SonarQube analysis for IEAD Church Management System..."

# Check if SonarScanner CLI is installed
if ! command -v sonar-scanner &> /dev/null; then
    echo "❌ SonarScanner CLI is not installed."
    echo "📥 Please install it from: https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/"
    echo "🍺 On macOS with Homebrew: brew install sonar-scanner"
    exit 1
fi

# Check if required environment variables are set
if [ -z "$SONAR_TOKEN" ]; then
    echo "❌ SONAR_TOKEN environment variable is not set."
    echo "🔑 Please set your SonarQube token: export SONAR_TOKEN=your_token_here"
    exit 1
fi

if [ -z "$SONAR_HOST_URL" ]; then
    echo "ℹ️  SONAR_HOST_URL not set, using SonarCloud default..."
    export SONAR_HOST_URL="https://sonarcloud.io"
fi

# Run TypeScript compilation check
echo "🔧 Checking TypeScript compilation..."
if ! deno check src/**/*.ts; then
    echo "⚠️  TypeScript compilation has issues, but continuing with analysis..."
fi

# Run tests if available
echo "🧪 Running tests..."
if deno task test 2>/dev/null; then
    echo "✅ Tests completed successfully"
else
    echo "⚠️  Tests failed or not available, continuing with analysis..."
fi

# Run SonarScanner
echo "🚀 Running SonarQube analysis..."
sonar-scanner \
  -Dsonar.projectKey=zlovtnik_iead \
  -Dsonar.organization=zlovtnik \
  -Dsonar.sources=src \
  -Dsonar.host.url=$SONAR_HOST_URL \
  -Dsonar.login=$SONAR_TOKEN \
  -Dsonar.typescript.file.suffixes=.ts,.tsx \
  -Dsonar.javascript.file.suffixes=.js,.jsx,.svelte \
  -Dsonar.exclusions="**/node_modules/**,**/.svelte-kit/**,**/dist/**,**/build/**" \
  -Dsonar.coverage.exclusions="**/*.test.ts,**/*.test.js,**/*.spec.ts,**/*.spec.js" \
  -Dsonar.sourceEncoding=UTF-8

if [ $? -eq 0 ]; then
    echo "✅ SonarQube analysis completed successfully!"
    echo "📊 View your results at: $SONAR_HOST_URL/dashboard?id=zlovtnik_iead"
else
    echo "❌ SonarQube analysis failed. Check the output above for details."
    exit 1
fi
