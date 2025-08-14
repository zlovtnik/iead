# Church Management System - Svelte 5 Frontend Specification

## Overview
This document outlines the requirements, design, and implementation tasks for building a Svelte 5 frontend application in TypeScript for the Church Management System. The frontend will be built in the `public/` directory and will consume the existing Lua-based REST API.

## API Routes Analysis

### Authentication Routes
- `POST /auth/login` - User login
- `POST /auth/logout` - User logout  
- `POST /auth/refresh` - Refresh token
- `GET /auth/me` - Get current user info (requires member+ role)
- `PUT /auth/password` - Change password (requires member+ role)

### User Management Routes (Admin Only)
- `GET /users` - List all users
- `POST /users` - Create new user
- `GET /users/{id}` - Get user by ID
- `PUT /users/{id}` - Update user
- `DELETE /users/{id}` - Deactivate user
- `POST /users/{id}/activate` - Activate user
- `POST /users/{id}/reset-password` - Reset user password
- `POST /users/{id}/change-role` - Change user role

### Member Management Routes
- `GET /members` - List all members (pastor+ role)
- `POST /members` - Create new member (pastor+ role)
- `GET /members/{id}` - Get member by ID (member access)
- `PUT /members/{id}` - Update member (member access)
- `DELETE /members/{id}` - Delete member (pastor+ role)

### Event Management Routes
- `GET /events` - List all events (member+ role)
- `POST /events` - Create new event (pastor+ role)
- `GET /events/{id}` - Get event by ID (member+ role)
- `PUT /events/{id}` - Update event (pastor+ role)
- `DELETE /events/{id}` - Delete event (pastor+ role)

### Attendance Routes
- `GET /attendance` - List all attendance (pastor+ role)
- `POST /attendance` - Create attendance record (pastor+ role)
- `GET /attendance/{id}` - Get attendance by ID (pastor+ role)
- `PUT /attendance/{id}` - Update attendance (pastor+ role)
- `DELETE /attendance/{id}` - Delete attendance (pastor+ role)
- `GET /events/{id}/attendance` - Get attendance for event (pastor+ role)
- `GET /members/{id}/attendance` - Get attendance for member (member access)

### Donation Routes
- `GET /donations` - List all donations (pastor+ role)
- `POST /donations` - Create donation record (pastor+ role)
- `GET /donations/{id}` - Get donation by ID (pastor+ role)
- `PUT /donations/{id}` - Update donation (pastor+ role)
- `DELETE /donations/{id}` - Delete donation (pastor+ role)
- `GET /members/{id}/donations` - Get donations by member (member access)

### Tithe Routes
- `GET /tithes` - List all tithes (pastor+ role)
- `POST /tithes` - Create tithe record (pastor+ role)
- `GET /tithes/{id}` - Get tithe by ID (pastor+ role)
- `PUT /tithes/{id}` - Update tithe (pastor+ role)
- `DELETE /tithes/{id}` - Delete tithe (pastor+ role)
- `POST /tithes/{id}/pay` - Mark tithe as paid (pastor+ role)
- `GET /members/{id}/tithes` - Get tithes by member (member access)
- `GET /members/{id}/tithe-calculation` - Calculate tithe for member (member access)
- `POST /tithes/generate-monthly` - Generate monthly tithes (pastor+ role)

### Volunteer Routes
- `GET /volunteers` - List all volunteers (pastor+ role)
- `POST /volunteers` - Create volunteer record (pastor+ role)
- `GET /volunteers/{id}` - Get volunteer by ID (pastor+ role)
- `PUT /volunteers/{id}` - Update volunteer (pastor+ role)
- `DELETE /volunteers/{id}` - Delete volunteer (pastor+ role)
- `GET /members/{id}/volunteers` - Get volunteer records by member (member access)
- `GET /events/{id}/volunteers` - Get volunteers for event (member+ role)

### Report Routes (Pastor+ Role)
- `GET /reports/member-attendance` - Member attendance report
- `GET /reports/event-attendance` - Event attendance report
- `GET /reports/donation-summary` - Donation summary report
- `GET /reports/top-donors` - Top donors report
- `GET /reports/volunteer-hours` - Volunteer hours report

### System Routes
- `GET /health` - Health check
- `GET /` - Home page

## Data Models

### User
```typescript
interface User {
  id: number;
  username: string;
  email: string;
  role: 'Admin' | 'Pastor' | 'Member';
  member_id?: number;
  is_active: boolean;
  failed_login_attempts: number;
  last_login?: string;
  password_reset_required: boolean;
  created_at: string;
}
```

### Member
```typescript
interface Member {
  id: number;
  name: string;
  email: string;
  phone?: string;
  salary?: number;
  created_at: string;
}
```

### Event
```typescript
interface Event {
  id: number;
  title: string;
  description?: string;
  start_date: string;
  end_date?: string;
  location?: string;
  created_at: string;
}
```

### Attendance
```typescript
interface Attendance {
  id: number;
  member_id: number;
  event_id: number;
  status: string;
  notes?: string;
  recorded_at: string;
}
```

### Donation
```typescript
interface Donation {
  id: number;
  member_id: number;
  amount: number;
  donation_date: string;
  category?: string;
  notes?: string;
  created_at: string;
}
```

### Tithe
```typescript
interface Tithe {
  id: number;
  member_id: number;
  amount: number;
  month: number;
  year: number;
  is_paid: boolean;
  paid_date?: string;
  created_at: string;
}
```

### Volunteer
```typescript
interface Volunteer {
  id: number;
  member_id: number;
  event_id: number;
  role: string;
  hours?: number;
  notes?: string;
  created_at: string;
}
```

## Permission System

### Role Hierarchy
1. **Admin** (Level 3) - Full system access, user management
2. **Pastor** (Level 2) - Church data management, reports
3. **Member** (Level 1) - Limited access to own data

### Access Patterns
- **member_access**: Users can access their own data or pastor+ can access any
- **pastor+ role**: Pastor and Admin roles
- **admin only**: Admin role only

## Frontend Architecture

### Technology Stack
- **Svelte 5** with TypeScript
- **SvelteKit** for routing and SSR
- **Tailwind CSS** for styling
- **Lucide Svelte** for icons
- **Zod** for runtime validation
- **Axios** for HTTP requests
- **Svelte Stores** for state management

### Directory Structure
```
public/
├── src/
│   ├── app.d.ts
│   ├── app.html
│   ├── lib/
│   │   ├── components/
│   │   │   ├── ui/          # Reusable UI components
│   │   │   ├── forms/       # Form components
│   │   │   ├── tables/      # Data table components
│   │   │   └── charts/      # Chart components
│   │   ├── stores/          # Svelte stores
│   │   ├── api/            # API client functions
│   │   ├── types/          # TypeScript type definitions
│   │   ├── utils/          # Utility functions
│   │   └── validators/     # Zod schemas
│   ├── routes/
│   │   ├── (auth)/         # Authentication routes
│   │   ├── (app)/          # Main application routes
│   │   └── +layout.svelte  # Root layout
│   └── static/            # Static assets
├── package.json
├── svelte.config.js
├── tailwind.config.js
├── tsconfig.json
└── vite.config.ts
```

## Implementation Tasks

### Phase 1: Project Setup and Authentication
1. **Initialize SvelteKit project with TypeScript**
   - Set up SvelteKit in public/ directory
   - Configure TypeScript, Tailwind CSS
   - Set up development tools (ESLint, Prettier)

2. **Create base API client**
   - HTTP client with interceptors
   - Token management
   - Error handling
   - Request/response typing

3. **Implement authentication system**
   - Login/logout functionality
   - Token refresh mechanism
   - Route protection
   - Authentication store

4. **Create base layout and navigation**
   - Responsive layout
   - Navigation menu with role-based visibility
   - User menu with logout

### Phase 2: Core Components and UI Library
1. **Build reusable UI components**
   - Button, Input, Select, Modal
   - Alert/Toast notifications
   - Loading states
   - Form validation

2. **Create data table component**
   - Sortable columns
   - Filtering
   - Pagination
   - Actions (edit, delete)

3. **Implement form components**
   - Form wrapper with validation
   - Field components
   - Error display

### Phase 3: Member Management
1. **Member list page**
   - Data table with search/filter
   - Role-based actions
   - Pagination

2. **Member detail/edit page**
   - View member information
   - Edit form (for authorized users)
   - Related data (attendance, donations, etc.)

3. **Create member page**
   - Member creation form
   - Validation
   - Success/error handling

### Phase 4: Event Management
1. **Event list page**
   - Calendar view option
   - List view with filters
   - Create event button (pastor+)

2. **Event detail page**
   - Event information
   - Attendance tracking
   - Volunteer management

3. **Event forms**
   - Create/edit event forms
   - Date/time pickers
   - Validation

### Phase 5: Attendance Management
1. **Attendance tracking**
   - Event attendance recording
   - Member attendance history
   - Bulk attendance updates

2. **Attendance reports**
   - Member attendance summary
   - Event attendance charts

### Phase 6: Financial Management
1. **Donation management**
   - Donation recording
   - Member donation history
   - Category management

2. **Tithe management**
   - Tithe calculation
   - Payment tracking
   - Monthly generation

3. **Financial reports**
   - Donation summaries
   - Top donors
   - Financial charts

### Phase 7: Volunteer Management
1. **Volunteer tracking**
   - Volunteer assignment
   - Hours tracking
   - Role management

2. **Volunteer reports**
   - Hours summaries
   - Event volunteers

### Phase 8: User Management (Admin)
1. **User list and management**
   - User CRUD operations
   - Role management
   - Account activation/deactivation

2. **Security features**
   - Password reset
   - Role changes
   - Activity monitoring

### Phase 9: Reports and Analytics
1. **Report dashboard**
   - Key metrics
   - Charts and graphs
   - Export functionality

2. **Advanced reports**
   - Custom date ranges
   - Filtered reports
   - PDF export

### Phase 10: Polish and Optimization
1. **Performance optimization**
   - Code splitting
   - Lazy loading
   - Caching strategies

2. **Mobile responsiveness**
   - Mobile-first design
   - Touch interactions
   - Responsive tables

3. **Accessibility**
   - ARIA labels
   - Keyboard navigation
   - Screen reader support

## Technical Requirements

### State Management
- Use Svelte stores for global state
- Separate stores for:
  - Authentication state
  - User data
  - App configuration
  - Loading states

### API Integration
- Type-safe API calls
- Error handling and retry logic
- Request/response interceptors
- Offline handling

### Routing
- Protected routes based on authentication
- Role-based route access
- Dynamic imports for code splitting

### Forms
- Reactive validation
- Type-safe form handling
- Zod schema validation
- Error display

### Security
- XSS prevention
- CSRF protection
- Secure token storage
- Input sanitization

## Design Requirements

### UI/UX Principles
- Clean, modern interface
- Intuitive navigation
- Consistent design patterns
- Accessible to all users

### Responsive Design
- Mobile-first approach
- Tablet and desktop optimizations
- Flexible layouts
- Touch-friendly interactions

### Color Scheme
- Primary: Church/spiritual theme
- Secondary: Professional blue/gray
- Success: Green
- Warning: Orange
- Error: Red

### Typography
- Clear, readable fonts
- Proper hierarchy
- Consistent sizing
- Good contrast ratios

## Development Guidelines

### Code Standards
- TypeScript strict mode
- ESLint and Prettier configuration
- Component composition over inheritance
- Single responsibility principle

### Testing Strategy
- Unit tests for utilities and stores
- Component testing with Testing Library
- E2E tests for critical flows
- API integration tests

### Performance
- Bundle size optimization
- Image optimization
- Lazy loading
- Efficient re-renders

## Deployment Considerations

### Build Process
- Production builds with optimizations
- Environment variable handling
- Asset optimization
- Source maps for debugging

### Integration
- Integration with existing Lua backend
- Static file serving
- API proxy configuration
- Production deployment strategy

## Success Metrics

### Functionality
- All CRUD operations working
- Proper authentication and authorization
- Role-based access control
- Data validation and error handling

### Performance
- Fast page load times (<2s)
- Smooth interactions
- Efficient data loading
- Mobile performance

### User Experience
- Intuitive navigation
- Clear feedback
- Responsive design
- Accessibility compliance

This specification provides a comprehensive roadmap for building a modern, type-safe, and user-friendly frontend for the Church Management System using Svelte 5 and TypeScript.
