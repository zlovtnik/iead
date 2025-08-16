# Church Management System

[![CI/CD Pipeline](https://github.com/zlovtnik/iead/actions/workflows/deploy-pipeline.yml/badge.svg)](https://github.com/zlovtnik/iead/actions/workflows/deploy-pipeline.yml)
[![Quality Gate](https://github.com/zlovtnik/iead/actions/workflows/quality-pipeline.yml/badge.svg)](https://github.com/zlovtnik/iead/actions/workflows/quality-pipeline.yml)
[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=zlovtnik_iead&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=zlovtnik_iead)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=zlovtnik_iead&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=zlovtnik_iead)

A modern, secure, and comprehensive church management system featuring a pure Lua backend with RESTful API and a Svelte 5 frontend. Built with enterprise-grade security, role-based access control, and production-ready deployment automation.

## 🎯 Project Status: **95% Complete - Production Ready**

### ✅ **Backend (100% Complete)**
- **Authentication & Authorization**: JWT-based authentication with role-based access control (Admin, Pastor, Member)
- **7 Core Models**: Members, Users, Events, Attendance, Donations, Tithes, Volunteers with full CRUD operations
- **Security**: Secure password hashing, rate limiting, SQL injection prevention, input validation
- **Database**: SQLite with comprehensive schema, migrations, and relationship management
- **Testing**: 85+ comprehensive tests with 100% pass rate and full coverage
- **API Documentation**: Complete RESTful API with proper HTTP status codes and error handling
- **Business Logic**: Automated tithe calculations, attendance tracking, donation management

### ✅ **Frontend (90% Complete)**
- **Modern UI**: Svelte 5 + TypeScript + Tailwind CSS responsive interface
- **Authentication**: Secure login/logout with session management and route protection
- **Dashboard**: Real-time metrics, charts, and overview of church operations
- **Member Management**: Complete member CRUD operations with role-based access
- **Data Tables**: Advanced sortable, filterable tables with pagination
- **Forms**: Type-safe forms with Zod validation and error handling
- **Responsive Design**: Mobile-first design that works on all devices

### ✅ **DevOps & Production (100% Complete)**
- **Containerization**: Multi-stage Docker builds with security hardening
- **CI/CD Pipeline**: Comprehensive GitHub Actions with quality gates and automated deployment
- **Monitoring**: Prometheus + Grafana monitoring stack with log aggregation (Loki)
- **Security**: Automated vulnerability scanning, security audits, and runtime monitoring
- **Deployment**: Production-ready deployment automation with blue-green deployments
- **Load Balancing**: Traefik reverse proxy with automatic SSL/TLS certificates

### 🔄 **In Progress (5% Remaining)**
- Final frontend polish and minor UI improvements
- Advanced reporting interface completion
- Email notification system integration

## 🚀 Features

### Core Functionality

- **Member Management** - Complete CRUD operations for church members with role-based access control
- **User Management** - Secure user accounts with Admin, Pastor, and Member roles
- **Event Management** - Schedule and manage church events with attendance tracking
- **Attendance Tracking** - Record and track member attendance at events with detailed reporting
- **Donation Management** - Track donations and offerings with categories and donor history
- **Tithe Management** - Automatic tithe calculations (10% of monthly salary) with payment tracking
- **Volunteer Scheduling** - Track volunteer hours, assignments, and event coordination
- **Advanced Reporting** - Generate comprehensive reports for all church operations

### Technical Features

- **Secure Authentication** - JWT-based authentication with bcrypt password hashing
- **Role-Based Access Control** - Three-tier permission system (Admin > Pastor > Member)
- **RESTful API Design** - Standard HTTP methods with proper status codes and error handling
- **Input Validation** - Comprehensive server-side validation with sanitization
- **SQL Injection Prevention** - Parameterized queries and secure database operations
- **Rate Limiting** - Protection against brute force attacks and API abuse
- **Session Management** - Secure session handling with automatic expiration
- **Database Integrity** - Foreign key constraints and transaction support

### Frontend Features

- **Modern UI/UX** - Clean, responsive interface built with Svelte 5 and Tailwind CSS
- **Real-time Dashboard** - Live metrics, charts, and church operation overview
- **Advanced Data Tables** - Sortable, filterable tables with pagination and bulk operations
- **Type-Safe Forms** - Reactive validation with Zod schemas and error handling
- **Responsive Design** - Mobile-first approach that works on all device sizes
- **Accessibility** - WCAG compliant components with proper ARIA support
- **Performance Optimized** - Code splitting, lazy loading, and efficient re-renders

## 📋 Prerequisites

### Backend Requirements
- [Lua](https://www.lua.org/download.html) (5.1 or higher)
- [LuaRocks](https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-macOS)
- SQLite3 (usually pre-installed on macOS/Linux)

### Frontend Requirements  
- [Node.js](https://nodejs.org/) (18 or higher)
- npm (comes with Node.js)

### Production Requirements
- [Docker](https://www.docker.com/get-started) and Docker Compose
- SSL certificates (for HTTPS in production)

## 🛠️ Installation & Development

### Quick Start (Development)

1. **Clone the repository**
```bash
git clone https://github.com/zlovtnik/iead.git
cd iead
```

2. **Install backend dependencies**
```bash
luarocks install luasql-sqlite3
luarocks install lua-cjson
luarocks install luasocket
luarocks install bcrypt
```

3. **Install frontend dependencies**
```bash
cd public
npm install
cd ..
```

4. **Initialize the database**
```bash
lua -e "require('src.db.schema').init()"
```

### Running the Application

1. **Start the backend server**
```bash
./scripts/start.sh
# OR
lua app.lua
```

2. **Start the frontend development server** (in a new terminal)
```bash
cd public
npm run dev
```

3. **Access the application**
   - Frontend: http://localhost:5173
   - Backend API: http://localhost:8080
   - Health Check: http://localhost:8080/health

### Testing & Validation

1. **Run comprehensive backend tests**
```bash
lua scripts/run_comprehensive_tests.lua
```

2. **Run frontend tests**
```bash
cd public
npm test
```

3. **Run security tests**
```bash
lua scripts/simple_security_test.lua
```

4. **Test with sample data**
```bash
lua scripts/simple_demo.lua
```

## 🧪 Testing

The system includes a comprehensive test suite with 85+ tests and 100% pass rate:

### Backend Testing

```bash
# Run all backend tests
lua scripts/run_comprehensive_tests.lua

# Run specific test categories
lua scripts/test_auth_middleware_integration.lua
lua scripts/test_secure_password_generation.lua
lua scripts/verify_security_fixes.lua

# Run performance tests
lua scripts/performance_test.lua

# Generate coverage report
lua scripts/coverage_analyzer.lua --html --output coverage-report.html
```

### Frontend Testing

```bash
cd public

# Run all tests
npm test

# Run tests with coverage
npm run test:coverage

# Run tests in watch mode
npm run test:watch

# Type checking
npx tsc --noEmit

# Linting
npm run lint
```

### Integration Testing

```bash
# Test API integration
lua scripts/api_test.lua

# Test authentication flow
lua scripts/test_auth_middleware_integration.lua

# Test rate limiting
lua scripts/test_rate_limit_isolated.lua
```

**Test Coverage Includes:**
- ✅ All model operations (CRUD, business logic, relationships)
- ✅ All controller endpoints with authentication and authorization
- ✅ HTTP utilities, validation, and error handling
- ✅ Security features (rate limiting, input sanitization)
- ✅ Database integrity and transaction handling
- ✅ Frontend components and user interactions

## 🚀 Production Deployment

### Option 1: Docker Compose (Recommended)

1. **Clone and configure**
```bash
git clone https://github.com/zlovtnik/iead.git
cd iead
cp .env.production.template .env.production
# Edit .env.production with your configuration
```

2. **Deploy with Docker Compose**
```bash
docker-compose -f docker-compose.production.yml up -d
```

This provides:
- Load-balanced application containers
- Traefik reverse proxy with automatic SSL
- Prometheus + Grafana monitoring
- Loki log aggregation
- Automated backups
- Health monitoring

### Option 2: Manual Build & Deployment

1. **Build the application**
```bash
./build.sh --env production --version 1.0.0
```

2. **Deploy the package**
```bash
# The build creates: dist/church-management-1.0.0.tar.gz
tar -xzf dist/church-management-1.0.0.tar.gz
cd church-management-1.0.0
./scripts/start-production.sh
```

### Environment Configuration

Key environment variables for production:

```bash
# Application
APP_ENV=production
HOST=0.0.0.0
PORT=8080
DB_PATH=/app/data/church_management.db

# Security
SESSION_SECRET=your-super-secure-session-secret-here-at-least-32-chars
JWT_SECRET=your-super-secure-jwt-secret-here-at-least-32-chars
BCRYPT_ROUNDS=12

# Redis (for sessions and caching)
REDIS_URL=redis://redis:6379

# Monitoring
PROMETHEUS_ENABLED=true
LOG_LEVEL=info
```

## 📊 API Documentation

### Authentication Endpoints

- `POST /auth/login` - User authentication
- `POST /auth/logout` - User logout
- `POST /auth/refresh` - Refresh authentication token
- `GET /auth/me` - Get current user information
- `PUT /auth/password` - Change user password

### Core Resource Endpoints

#### Members
- `GET /members` - List all members (Pastor+ role)
- `POST /members` - Create new member (Pastor+ role)  
- `GET /members/{id}` - Get member details (member access control)
- `PUT /members/{id}` - Update member (member access control)
- `DELETE /members/{id}` - Delete member (Pastor+ role)

#### Events
- `GET /events` - List all events (Member+ role)
- `POST /events` - Create new event (Pastor+ role)
- `GET /events/{id}` - Get event details (Member+ role)
- `PUT /events/{id}` - Update event (Pastor+ role)
- `DELETE /events/{id}` - Delete event (Pastor+ role)

#### Attendance
- `GET /attendance` - List attendance records (Pastor+ role)
- `POST /attendance` - Record attendance (Pastor+ role)
- `GET /events/{id}/attendance` - Get event attendance (Pastor+ role)
- `GET /members/{id}/attendance` - Get member attendance (member access)

#### Donations & Tithes
- `GET /donations` - List donations (Pastor+ role)
- `POST /donations` - Record donation (Pastor+ role)
- `GET /tithes` - List tithes (Pastor+ role)
- `POST /tithes/generate-monthly` - Generate monthly tithes (Pastor+ role)
- `POST /tithes/{id}/pay` - Mark tithe as paid (Pastor+ role)

#### Volunteers
- `GET /volunteers` - List volunteers (Pastor+ role)
- `POST /volunteers` - Create volunteer assignment (Pastor+ role)
- `GET /events/{id}/volunteers` - Get event volunteers (Member+ role)

#### Reports
- `GET /reports/member-attendance` - Member attendance report
- `GET /reports/donation-summary` - Donation summary report  
- `GET /reports/volunteer-hours` - Volunteer hours report

### System Endpoints
- `GET /health` - Application health check
- `GET /` - Application homepage

For detailed API documentation with request/response examples, see [docs/API_LAYER_DOCUMENTATION.md](docs/API_LAYER_DOCUMENTATION.md).

## 🔒 Security Features

### Authentication & Authorization
- **JWT-based Authentication** with secure token management
- **Role-Based Access Control** (Admin > Pastor > Member hierarchy)
- **Session Management** with automatic expiration and renewal
- **Password Security** with bcrypt hashing and strength validation
- **Rate Limiting** to prevent brute force attacks

### Data Protection
- **SQL Injection Prevention** using parameterized queries
- **Input Validation & Sanitization** on all user inputs
- **XSS Protection** with proper output encoding
- **CSRF Protection** with token validation
- **Secure Headers** for production deployments

### Infrastructure Security
- **Container Security** with non-root users and minimal attack surface
- **Network Security** with proper service isolation
- **SSL/TLS Encryption** for all production communications
- **Vulnerability Scanning** with automated security audits
- **Security Monitoring** with runtime threat detection

For detailed security documentation, see [docs/SECURITY_FIXES_SUMMARY.md](docs/SECURITY_FIXES_SUMMARY.md).

## 📈 Monitoring & Observability

### Application Monitoring
- **Health Checks** at multiple levels (container, application, database)
- **Performance Metrics** with Prometheus integration
- **Real-time Dashboards** using Grafana
- **Log Aggregation** with structured logging and Loki
- **Error Tracking** with automated alerting

### Production Metrics
- API response times and throughput
- Database query performance
- User authentication patterns
- System resource utilization
- Security event monitoring

### Alerting
- Service availability monitoring
- Performance threshold alerts
- Security incident notifications
- Database backup verification
- SSL certificate expiration warnings

## 🔄 CI/CD Pipeline

### Automated Quality Gates
- **Code Quality** analysis with comprehensive linting
- **Security Scanning** for vulnerabilities and dependencies
- **Automated Testing** with 85+ test suite
- **Performance Benchmarking** with load testing
- **Documentation** validation and generation

### Deployment Automation
- **Multi-Environment** support (development, staging, production)
- **Blue-Green Deployments** with automatic rollback
- **Database Migrations** with version control
- **Container Building** with multi-architecture support
- **Security Scanning** of container images

### Pipeline Stages
1. **Quality Gate** - Code quality, security, and testing validation
2. **Build & Test** - Multi-platform Docker image builds with caching  
3. **Integration Tests** - Full application stack testing
4. **Staging Deployment** - Automated staging environment deployment
5. **Production Deployment** - Blue-green production deployment with rollback
6. **Performance Testing** - Post-deployment performance validation
7. **Security Monitoring** - Continuous security monitoring setup

## 💻 Development

### Architecture Overview
- **Backend**: Pure Lua with OpenResty for production performance
- **Frontend**: Svelte 5 + TypeScript for modern, reactive UI
- **Database**: SQLite with comprehensive schema and migrations
- **API**: RESTful design with proper HTTP semantics
- **Authentication**: JWT tokens with role-based access control
- **Security**: Defense-in-depth with multiple security layers

### Development Workflow
1. **Feature Development** with comprehensive testing
2. **Code Review** with automated quality checks
3. **Integration Testing** in staging environment
4. **Security Validation** with automated scanning
5. **Performance Testing** with load testing
6. **Production Deployment** with monitoring

### Code Quality Standards
- **100% Test Coverage** requirement for new features
- **Security-First** development with threat modeling
- **Performance Optimization** with profiling and benchmarking
- **Documentation** requirements for all public APIs
- **Type Safety** with TypeScript and Lua validation

For development guidelines, see [docs/README.md](docs/README.md).

## 📚 Documentation

- [API Documentation](docs/API_LAYER_DOCUMENTATION.md) - Complete API reference
- [Security Guide](docs/SECURITY_FIXES_SUMMARY.md) - Security implementation details
- [Deployment Guide](docs/PHASE_5_SUMMARY.md) - Production deployment and monitoring
- [Frontend Specification](docs/SVELTE_FRONTEND_SPEC.md) - Frontend architecture and components
- [Testing Guide](docs/TESTING_IMPLEMENTATION_SUMMARY.md) - Testing strategies and implementation
- [Command Reference](docs/COMMAND_INJECTION_FIX.md) - Security fixes and best practices

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure all tests pass and follow the security guidelines outlined in the documentation.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏗️ Built With

### Backend Technologies
- **Lua 5.1+** - Core programming language
- **OpenResty** - High-performance web platform
- **SQLite** - Embedded database
- **bcrypt** - Password hashing
- **lua-cjson** - JSON processing

### Frontend Technologies  
- **Svelte 5** - Reactive web framework
- **TypeScript** - Type-safe JavaScript
- **Tailwind CSS** - Utility-first CSS framework
- **Vite** - Fast build tool
- **Zod** - Runtime type validation

### DevOps & Infrastructure
- **Docker** - Containerization
- **GitHub Actions** - CI/CD automation
- **Prometheus** - Metrics collection
- **Grafana** - Monitoring dashboards
- **Loki** - Log aggregation
- **Traefik** - Reverse proxy and load balancer

---

**Church Management System** - A secure, scalable, and modern solution for church administration.

*Developed with ❤️ for church communities worldwide.*
