# System Architecture

## Current Architecture

### Core Components
```
┌─────────────────────────────────────────────────────────┐
│                    HTTP Server                         │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────────┐  │
│  │ Controllers │  │ Middleware  │  │     Router     │  │
│  └──────┬──────┘  └──────┬──────┘  └────────┬───────┘  │
│         │                │                  │          │
│  ┌──────▼───────────────▼──────────────────▼───────┐  │
│  │              Business Logic (Inline)            │  │
│  └───────────────────────┬────────────────────────┘  │
│                          │                           │
│                  ┌───────▼────────┐                  │
│                  │ Direct DB Calls │                 │
│                  └────────────────┘                  │
└─────────────────────────────────────────────────────┘
```

## Target Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    API Layer                           │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────────┐  │
│  │ Controllers │◄─┤ Middleware  │◄─┤     Router     │  │
│  └──────┬──────┘  └─────────────┘  └────────────────┘  │
│         │                                               │
│  ┌──────▼──────┐    ┌──────────────────────────────┐    │
│  │  Services   │◄───┤        Validators            │    │
│  └──────┬──────┘    └──────────────────────────────┘    │
│         │                                               │
│  ┌──────▼──────┐    ┌──────────────────────────────┐    │
│  │ Repositories│    │          DTOs                │    │
│  └──────┬──────┘    └──────────────────────────────┘    │
│         │                                               │
│  ┌──────▼───────────────────────────────────────────┐   │
│  │               Database Layer                     │   │
│  │  ┌─────────────┐  ┌─────────────────────────┐    │   │
│  │  │ Connections │  │       Migrations        │    │   │
│  │  └─────────────┘  └─────────────────────────┘    │   │
└─────────────────────────────────────────────────────┘
```

## Key Improvements

### 1. Security Layer
- **Authentication**: JWT with refresh tokens
- **Authorization**: Role-based access control
- **Validation**: Request/response validation
- **Rate Limiting**: Per-route and global

### 2. Business Logic
- **Services**: Encapsulate business rules
- **Validation**: Centralized validation logic
- **Transactions**: Proper transaction management

### 3. Data Access
- **Repositories**: Abstract database operations
- **Connection Pooling**: Efficient DB connections
- **Migrations**: Versioned database schema changes

## Implementation Details

### API Endpoints
```
/api/v1/
  /auth
    POST /login
    POST /refresh
    GET  /me
    POST /logout
    
  /members
    GET    /              # List members
    POST   /              # Create member
    GET    /:id           # Get member
    PUT    /:id           # Update member
    DELETE /:id           # Delete member
    
  # Similar structures for events, attendance, etc.
```

### Error Handling
```lua
{
  "error": {
    "code": "INVALID_INPUT",
    "message": "Validation failed",
    "details": {
      "email": "Invalid email format",
      "password": "Must be at least 8 characters"
    },
    "timestamp": "2023-01-01T00:00:00Z",
    "request_id": "req_123456789"
  }
}
```

### Database Schema
Key tables:
- `users` - System users
- `sessions` - Active user sessions
- `members` - Church members
- `events` - Church events
- `attendance` - Event attendance
- `donations` - Donation records
- `tithes` - Tithe payments

### Security Measures
- Prepared statements for all queries
- Input validation and sanitization
- Password hashing (bcrypt)
- HTTPS enforcement
- CORS configuration
- Rate limiting
- Request validation

## Performance Considerations

### Caching Strategy
- Redis for session storage
- Response caching for public endpoints
- Entity caching for frequently accessed data

### Database Optimization
- Proper indexing
- Query optimization
- Connection pooling
- Read replicas for reporting

## Monitoring

### Logging
- Structured JSON logs
- Request/response logging
- Error logging with stack traces
- Audit logging for sensitive operations

### Metrics
- Request rates
- Error rates
- Response times
- Database query performance

## Deployment

### Development
- Local SQLite database
- Hot-reloading
- Debug tools

### Production
- PostgreSQL database
- Connection pooling
- Read replicas
- Backup strategy
- Monitoring and alerting
