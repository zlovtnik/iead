# Form System

A comprehensive form system built with Svelte 5 and Zod validation that provides type-safe forms with excellent user experience and accessibility.

## Components

### FormWrapper

The main form component that handles validation, submission, and error management.

**Props:**
- `schema?: z.ZodSchema<T>` - Zod schema for validation
- `initialData?: Partial<T>` - Initial form data
- `onsubmit: (data: T) => Promise<void> | void` - Form submission handler
- `submitText?: string` - Submit button text (default: "Submit")
- `submitVariant?: ButtonVariant` - Submit button variant (default: "primary")
- `resetOnSubmit?: boolean` - Reset form after successful submission (default: false)
- `validateOnChange?: boolean` - Validate fields on change (default: false)
- `validateOnBlur?: boolean` - Validate fields on blur (default: true)
- `disabled?: boolean` - Disable the entire form (default: false)

**Context provided to children:**
- `formData` - Current form data
- `errors` - Current form errors
- `isSubmitting` - Whether form is currently submitting
- `hasSubmitted` - Whether form has been submitted at least once
- `handleFieldChange(fieldName, value)` - Handle field value changes
- `handleFieldBlur(fieldName, value)` - Handle field blur events
- `resetForm()` - Reset form to initial state
- `setFormData(data)` - Set form data programmatically
- `setFormErrors(errors)` - Set form errors programmatically
- `getFormData()` - Get current form data
- `validateForm()` - Validate entire form
- `isValid()` - Check if form is valid
- `isSubmitting()` - Check if form is submitting

### FormField

A versatile form field component that supports various input types with built-in validation display.

**Props:**
- `name: string` - Field name (required)
- `label?: string` - Field label
- `error?: string` - Error message to display
- `helperText?: string` - Helper text
- `required?: boolean` - Whether field is required (default: false)
- `disabled?: boolean` - Whether field is disabled (default: false)
- `readonly?: boolean` - Whether field is readonly (default: false)
- `fullWidth?: boolean` - Whether field should take full width (default: false)
- `type?: string` - Input type (default: "text")
- `onchange?: (value: any) => void` - Change handler
- `onblur?: (event: FocusEvent) => void` - Blur handler
- `onfocus?: (event: FocusEvent) => void` - Focus handler

**Supported Types:**
- `text`, `email`, `password`, `number`, `tel`, `url`, `search`, `date`, `datetime-local`, `time`
- `textarea` - Multi-line text input
- `select` - Dropdown selection (requires `options` prop)

**Additional Props for Select:**
- `options: Array<{value: string|number, label: string, disabled?: boolean}>` - Select options
- `placeholder?: string` - Placeholder text

**Additional Props for Textarea:**
- `rows?: number` - Number of rows (default: 3)
- `resize?: boolean` - Allow resizing (default: true)

### ValidationError

A simple component for displaying validation errors.

**Props:**
- `error?: string | string[]` - Error message(s) to display

## Validation Utilities

### formatZodErrors(error: z.ZodError): FormErrors

Formats Zod validation errors into a user-friendly format.

### formatApiErrors(apiError: any): FormErrors

Formats API validation errors into form errors.

### validateField(schema, value, fieldName): string | null

Validates a single field value against a schema.

### createDebouncedValidator(schema, callback, delay)

Creates a debounced validation function.

## Common Validators

Pre-built validation schemas for common use cases:

- `requiredString(message?)` - Required string field
- `optionalString` - Optional string field
- `email` - Email validation
- `phone` - Phone number validation
- `positiveNumber` - Positive number validation
- `nonNegativeNumber` - Non-negative number validation
- `currency` - Currency amount validation
- `percentage` - Percentage validation
- `dateString` - Date string validation
- `futureDate` - Future date validation
- `pastDate` - Past date validation
- `password` - Strong password validation
- `url` - URL validation

## Usage Examples

### Basic Form

```svelte
<script lang="ts">
  import { FormWrapper, FormField } from '$lib/components/forms';
  import { z } from 'zod';
  
  const schema = z.object({
    name: z.string().min(1, 'Name is required'),
    email: z.string().email('Invalid email')
  });
  
  async function handleSubmit(data) {
    console.log('Form data:', data);
  }
</script>

<FormWrapper {schema} onsubmit={handleSubmit} let:formContext>
  <FormField
    name="name"
    label="Name"
    required
    bind:value={formContext.formData.name}
    error={formContext.errors.name}
    onchange={(value) => formContext.handleFieldChange('name', value)}
    onblur={() => formContext.handleFieldBlur('name', formContext.formData.name)}
  />
  
  <FormField
    name="email"
    label="Email"
    type="email"
    required
    bind:value={formContext.formData.email}
    error={formContext.errors.email}
    onchange={(value) => formContext.handleFieldChange('email', value)}
    onblur={() => formContext.handleFieldBlur('email', formContext.formData.email)}
  />
</FormWrapper>
```

### Form with Select and Textarea

```svelte
<FormWrapper {schema} onsubmit={handleSubmit} let:formContext>
  <FormField
    name="category"
    label="Category"
    type="select"
    options={[
      { value: 'option1', label: 'Option 1' },
      { value: 'option2', label: 'Option 2' }
    ]}
    bind:value={formContext.formData.category}
    error={formContext.errors.category}
    onchange={(value) => formContext.handleFieldChange('category', value)}
  />
  
  <FormField
    name="description"
    label="Description"
    type="textarea"
    rows={4}
    bind:value={formContext.formData.description}
    error={formContext.errors.description}
    onchange={(value) => formContext.handleFieldChange('description', value)}
  />
</FormWrapper>
```

### Advanced Form with Custom Validation

```svelte
<script lang="ts">
  import { FormWrapper, FormField } from '$lib/components/forms';
  import { createDebouncedValidator } from '$lib/utils/validation';
  import { z } from 'zod';
  
  const schema = z.object({
    username: z.string().min(3, 'Username must be at least 3 characters'),
    email: z.string().email('Invalid email')
  });
  
  let usernameAvailable = $state(true);
  
  const checkUsername = createDebouncedValidator(
    z.string().min(3),
    async (errors) => {
      if (!errors) {
        // Check username availability
        const response = await fetch(`/api/check-username?username=${formData.username}`);
        const result = await response.json();
        usernameAvailable = result.available;
      }
    },
    500
  );
  
  async function handleSubmit(data) {
    if (!usernameAvailable) {
      throw { details: { username: ['Username is not available'] } };
    }
    // Submit form
  }
</script>

<FormWrapper
  {schema}
  onsubmit={handleSubmit}
  validateOnChange={true}
  let:formContext
>
  <FormField
    name="username"
    label="Username"
    required
    bind:value={formContext.formData.username}
    error={formContext.errors.username || (!usernameAvailable ? 'Username not available' : '')}
    onchange={(value) => {
      formContext.handleFieldChange('username', value);
      checkUsername({ username: value });
    }}
  />
</FormWrapper>
```

## Accessibility Features

- Proper ARIA labels and descriptions
- Screen reader support with role="alert" for errors
- Keyboard navigation support
- Focus management
- High contrast error display
- Semantic HTML structure

## Styling

The form system uses Tailwind CSS classes and follows the design system color palette:

- Primary colors for focus states
- Error colors for validation errors
- Secondary colors for labels and helper text
- Consistent spacing and typography

All components are fully customizable through CSS classes and can be styled to match your design system.