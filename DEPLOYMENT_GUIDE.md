# Church Management System - Deployment Guide

This guide covers multiple deployment options for your church management system, from simple cloud platforms to full Kubernetes orchestration.

## 🚀 Quick Deployment Options (Easiest to Hardest)

### 1. Render (Simplest - Already Configured!)
**✅ You already have this configured in `render.yaml`**

```bash
# Just push to GitHub and connect to Render
git push origin main
```

**Pros**: Zero configuration, automatic PostgreSQL, SSL, monitoring
**Cons**: Limited scaling options, vendor lock-in
**Cost**: ~$7-25/month

### 2. Docker Compose (Local/VPS)
```bash
# Local development
docker-compose up

# Production on any VPS with Docker
docker-compose -f docker-compose.prod.yml up -d
```

**Pros**: Simple, runs anywhere with Docker, easy debugging
**Cons**: Single server, manual scaling
**Cost**: VPS cost only (~$5-20/month)

### 3. Kubernetes (Most Powerful)
```bash
# Using raw Kubernetes manifests
kubectl apply -f k8s/deployment.yaml

# Using Helm (recommended)
helm install church-management ./helm/church-management
```

**Pros**: Auto-scaling, high availability, professional grade
**Cons**: Complex setup, requires K8s knowledge
**Cost**: Varies by provider ($50-500+/month)

## 📋 Detailed Deployment Instructions

### Option 1: Render (Recommended for Beginners)

1. **Push your code to GitHub**:
   ```bash
   git add .
   git commit -m "Add PostgreSQL migration and deployment configs"
   git push origin main
   ```

2. **Create Render account** at [render.com](https://render.com)

3. **Create Blueprint service**:
   - Connect your GitHub repository
   - Render will automatically detect `render.yaml`
   - Set environment variable: `DOCKER_USERNAME=your-docker-hub-username`

4. **Deploy**: Render handles everything automatically!

### Option 2: Kubernetes on Cloud Providers

#### Google Kubernetes Engine (GKE)
```bash
# Create cluster
gcloud container clusters create church-management --num-nodes=2

# Deploy with Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install church-management ./helm/church-management \
  --set image.repository=YOUR_DOCKER_USERNAME/church-management \
  --set ingress.hosts[0].host=your-domain.com
```

#### Amazon EKS
```bash
# Create cluster (using eksctl)
eksctl create cluster --name church-management --region us-west-2 --nodes 2

# Deploy
kubectl apply -f k8s/deployment.yaml
```

#### Azure AKS
```bash
# Create cluster
az aks create --resource-group myResourceGroup --name church-management --node-count 2

# Deploy
helm install church-management ./helm/church-management
```

### Option 3: Alternative Cloud Platforms

#### Railway
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway link
railway up
```

#### Fly.io
```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Deploy
fly launch
fly deploy
```

#### DigitalOcean App Platform
- Upload your repository to GitHub
- Create new app in DigitalOcean
- Select your repository
- Configure environment variables

## 🔧 Configuration for Each Platform

### Environment Variables Needed:
```env
DB_HOST=your-postgres-host
DB_PORT=5432
DB_NAME=church_management
DB_USER=postgres
DB_PASSWORD=your-secure-password
APP_HOST=0.0.0.0
APP_PORT=8080
LUA_ENV=production
```

### Docker Image Requirements:
1. Build and push your image:
   ```bash
   docker build -t your-username/church-management:latest .
   docker push your-username/church-management:latest
   ```

2. Update deployment files with your image name

## 📊 Deployment Comparison

| Platform | Setup Time | Cost/Month | Scaling | SSL | Database |
|----------|------------|------------|---------|-----|----------|
| Render | 5 min | $7-25 | Auto | ✅ | Managed |
| Docker Compose | 10 min | $5-20 | Manual | Manual | Self-hosted |
| Kubernetes | 30-60 min | $50+ | Auto | ✅ | Configurable |
| Railway | 5 min | $5-20 | Auto | ✅ | Add-on |
| Fly.io | 10 min | $0-30 | Auto | ✅ | Add-on |

## 🎯 Recommendations

- **For MVP/Testing**: Use Render (already configured!)
- **For Learning**: Try Docker Compose locally
- **For Production Scale**: Use Kubernetes with Helm
- **For Budget**: DigitalOcean Droplet with Docker Compose

## 🔒 Security Checklist

- [ ] Change default passwords in all configs
- [ ] Enable SSL/TLS certificates
- [ ] Configure firewall rules
- [ ] Set up monitoring and logging
- [ ] Regular database backups
- [ ] Update dependencies regularly

Your system is now ready for deployment on any of these platforms!
