# UI Components Library

This directory contains the core UI components for the Church Management System frontend. All components are built with Svelte 5, TypeScript, and Tailwind CSS.

## Components

### Button
A versatile button component with multiple variants, sizes, and states.

**Props:**
- `variant`: 'primary' | 'secondary' | 'success' | 'warning' | 'error' | 'ghost' | 'outline'
- `size`: 'sm' | 'md' | 'lg'
- `loading`: boolean
- `disabled`: boolean
- `fullWidth`: boolean

**Usage:**
```svelte
<Button variant="primary" size="md" onclick={handleClick}>
  Click me
</Button>
```

### Input
A form input component with label, validation, and helper text support.

**Props:**
- `label`: string
- `error`: string
- `helperText`: string
- `required`: boolean
- `fullWidth`: boolean
- `leftIcon`: snippet
- `rightIcon`: snippet

**Usage:**
```svelte
<Input 
  label="Email Address" 
  type="email"
  required={true}
  error={emailError}
  helperText="We'll never share your email"
/>
```

### Modal
A modal dialog component with backdrop, keyboard navigation, and focus management.

**Props:**
- `open`: boolean
- `title`: string
- `size`: 'sm' | 'md' | 'lg' | 'xl' | 'full'
- `closable`: boolean

**Usage:**
```svelte
<Modal open={showModal} title="Confirm Action" size="md">
  <p>Are you sure you want to continue?</p>
  
  {#snippet footer()}
    <Button variant="ghost" onclick={() => showModal = false}>Cancel</Button>
    <Button variant="primary" onclick={handleConfirm}>Confirm</Button>
  {/snippet}
</Modal>
```

### Toast
Individual toast notification component (usually used via ToastContainer).

**Props:**
- `type`: 'success' | 'error' | 'warning' | 'info'
- `title`: string
- `message`: string
- `duration`: number
- `closable`: boolean

### ToastContainer
Container component that manages and displays toast notifications.

**Usage:**
```svelte
<!-- Add to your root layout -->
<ToastContainer />

<!-- Use the toast store to show notifications -->
<script>
  import { toastStore } from '$lib/stores/ui';
  
  function showSuccess() {
    toastStore.success('Operation completed successfully!', 'Success');
  }
</script>
```

### Loading
A loading spinner component with different sizes and overlay support.

**Props:**
- `size`: 'sm' | 'md' | 'lg' | 'xl'
- `color`: 'primary' | 'secondary' | 'white'
- `text`: string
- `overlay`: boolean

**Usage:**
```svelte
<Loading size="md" text="Loading..." />

<!-- For overlay loading -->
<Loading overlay={true} text="Processing..." />
```

### Skeleton
A skeleton loading component for content placeholders.

**Props:**
- `width`: string (Tailwind class)
- `height`: string (Tailwind class)
- `rounded`: boolean
- `lines`: number

**Usage:**
```svelte
<Skeleton />
<Skeleton lines={3} />
<Skeleton width="w-32" height="h-8" rounded={true} />
```

## Design System

The components use a consistent design system based on Tailwind CSS:

### Colors
- **Primary**: Blue tones for main actions
- **Secondary**: Gray tones for neutral elements
- **Success**: Green tones for positive feedback
- **Warning**: Orange tones for caution
- **Error**: Red tones for errors and destructive actions

### Typography
- **Font Family**: Inter (sans-serif)
- **Sizes**: Responsive scale from xs to 6xl

### Spacing
- **Base Unit**: 4px
- **Scale**: Consistent spacing using Tailwind's spacing scale

### Accessibility
All components include:
- Proper ARIA labels and descriptions
- Keyboard navigation support
- Focus management
- Screen reader compatibility
- High contrast support

## Testing

Component tests are located alongside each component file. Run tests with:

```bash
deno task test
```

## Demo

View all components in action at `/demo` route when running the development server.