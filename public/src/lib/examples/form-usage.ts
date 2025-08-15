/**
 * Example usage of the form system components
 * This file demonstrates how to use FormWrapper and FormField together
 */

// Example 1: Basic member form
export const memberFormExample = `
<script lang="ts">
  import { FormWrapper, FormField } from '$lib/components/forms';
  import { memberSchema, type Member } from '$lib/validators/member';
  
  let initialData: Partial<Member> = {
    name: '',
    email: '',
    phone: '',
    salary: undefined
  };
  
  async function handleSubmit(data: Member) {
    try {
      // Submit to API
      const response = await fetch('/api/members', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
      });
      
      if (!response.ok) {
        throw await response.json();
      }
      
      console.log('Member created successfully');
    } catch (error) {
      console.error('Failed to create member:', error);
      throw error; // Re-throw to let FormWrapper handle it
    }
  }
</script>

<FormWrapper
  schema={memberSchema}
  {initialData}
  onsubmit={handleSubmit}
  submitText="Create Member"
  resetOnSubmit={true}
  let:formContext
>
  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <FormField
      name="name"
      label="Full Name"
      type="text"
      required
      fullWidth
      bind:value={formContext.formData.name}
      error={formContext.errors.name}
      onchange={(value) => formContext.handleFieldChange('name', value)}
      onblur={() => formContext.handleFieldBlur('name', formContext.formData.name)}
    />
    
    <FormField
      name="email"
      label="Email Address"
      type="email"
      required
      fullWidth
      bind:value={formContext.formData.email}
      error={formContext.errors.email}
      onchange={(value) => formContext.handleFieldChange('email', value)}
      onblur={() => formContext.handleFieldBlur('email', formContext.formData.email)}
    />
    
    <FormField
      name="phone"
      label="Phone Number"
      type="tel"
      fullWidth
      bind:value={formContext.formData.phone}
      error={formContext.errors.phone}
      onchange={(value) => formContext.handleFieldChange('phone', value)}
      onblur={() => formContext.handleFieldBlur('phone', formContext.formData.phone)}
      helperText="Optional - Include country code if international"
    />
    
    <FormField
      name="salary"
      label="Annual Salary"
      type="number"
      fullWidth
      bind:value={formContext.formData.salary}
      error={formContext.errors.salary}
      onchange={(value) => formContext.handleFieldChange('salary', value)}
      onblur={() => formContext.handleFieldBlur('salary', formContext.formData.salary)}
      helperText="Used for tithe calculations"
      min="0"
      step="0.01"
    />
  </div>
</FormWrapper>
`;

// Example 2: Login form with custom styling
export const loginFormExample = `
<script lang="ts">
  import { FormWrapper, FormField } from '$lib/components/forms';
  import { loginSchema, type LoginCredentials } from '$lib/validators/auth';
  import { authStore } from '$lib/stores/auth';
  
  async function handleLogin(credentials: LoginCredentials) {
    await authStore.login(credentials);
  }
</script>

<div class="max-w-md mx-auto">
  <FormWrapper
    schema={loginSchema}
    onsubmit={handleLogin}
    submitText="Sign In"
    class="space-y-6"
    let:formContext
  >
    <div class="text-center mb-6">
      <h2 class="text-2xl font-bold text-secondary-900">Welcome Back</h2>
      <p class="text-secondary-600">Please sign in to your account</p>
    </div>
    
    <FormField
      name="username"
      label="Username"
      type="text"
      required
      fullWidth
      bind:value={formContext.formData.username}
      error={formContext.errors.username}
      onchange={(value) => formContext.handleFieldChange('username', value)}
      onblur={() => formContext.handleFieldBlur('username', formContext.formData.username)}
      autocomplete="username"
    />
    
    <FormField
      name="password"
      label="Password"
      type="password"
      required
      fullWidth
      bind:value={formContext.formData.password}
      error={formContext.errors.password}
      onchange={(value) => formContext.handleFieldChange('password', value)}
      onblur={() => formContext.handleFieldBlur('password', formContext.formData.password)}
      autocomplete="current-password"
    />
  </FormWrapper>
</div>
`;

// Example 3: Form with select and textarea fields
export const eventFormExample = `
<script lang="ts">
  import { FormWrapper, FormField } from '$lib/components/forms';
  import { z } from 'zod';
  
  const eventSchema = z.object({
    title: z.string().min(1, 'Event title is required'),
    description: z.string().optional(),
    category: z.enum(['service', 'meeting', 'social', 'outreach']),
    start_date: z.string().min(1, 'Start date is required'),
    location: z.string().optional()
  });
  
  const categoryOptions = [
    { value: 'service', label: 'Church Service' },
    { value: 'meeting', label: 'Meeting' },
    { value: 'social', label: 'Social Event' },
    { value: 'outreach', label: 'Outreach' }
  ];
  
  async function handleSubmit(data: any) {
    console.log('Event data:', data);
  }
</script>

<FormWrapper
  schema={eventSchema}
  onsubmit={handleSubmit}
  submitText="Create Event"
  let:formContext
>
  <FormField
    name="title"
    label="Event Title"
    type="text"
    required
    fullWidth
    bind:value={formContext.formData.title}
    error={formContext.errors.title}
    onchange={(value) => formContext.handleFieldChange('title', value)}
    onblur={() => formContext.handleFieldBlur('title', formContext.formData.title)}
  />
  
  <FormField
    name="category"
    label="Event Category"
    type="select"
    required
    fullWidth
    options={categoryOptions}
    placeholder="Select a category"
    bind:value={formContext.formData.category}
    error={formContext.errors.category}
    onchange={(value) => formContext.handleFieldChange('category', value)}
    onblur={() => formContext.handleFieldBlur('category', formContext.formData.category)}
  />
  
  <FormField
    name="start_date"
    label="Start Date & Time"
    type="datetime-local"
    required
    fullWidth
    bind:value={formContext.formData.start_date}
    error={formContext.errors.start_date}
    onchange={(value) => formContext.handleFieldChange('start_date', value)}
    onblur={() => formContext.handleFieldBlur('start_date', formContext.formData.start_date)}
  />
  
  <FormField
    name="location"
    label="Location"
    type="text"
    fullWidth
    bind:value={formContext.formData.location}
    error={formContext.errors.location}
    onchange={(value) => formContext.handleFieldChange('location', value)}
    onblur={() => formContext.handleFieldBlur('location', formContext.formData.location)}
    helperText="Optional - Leave blank for online events"
  />
  
  <FormField
    name="description"
    label="Description"
    type="textarea"
    fullWidth
    rows={4}
    bind:value={formContext.formData.description}
    error={formContext.errors.description}
    onchange={(value) => formContext.handleFieldChange('description', value)}
    onblur={() => formContext.handleFieldBlur('description', formContext.formData.description)}
    helperText="Optional - Provide additional details about the event"
  />
</FormWrapper>
`;

// Example 4: Form with custom validation and error recovery
export const advancedFormExample = `
<script lang="ts">
  import { FormWrapper, FormField, ValidationError } from '$lib/components/forms';
  import { z } from 'zod';
  import { createDebouncedValidator } from '$lib/utils/validation';
  
  const schema = z.object({
    username: z.string()
      .min(3, 'Username must be at least 3 characters')
      .regex(/^[a-zA-Z0-9_]+$/, 'Username can only contain letters, numbers, and underscores'),
    email: z.string().email('Please enter a valid email address'),
    confirmEmail: z.string()
  }).refine((data) => data.email === data.confirmEmail, {
    message: "Email addresses don't match",
    path: ["confirmEmail"]
  });
  
  let usernameAvailable = $state(true);
  let checkingUsername = $state(false);
  
  // Debounced username availability check
  const checkUsername = createDebouncedValidator(
    z.string().min(3),
    async (errors) => {
      if (!errors) {
        checkingUsername = true;
        try {
          const response = await fetch(\`/api/check-username?username=\${formData.username}\`);
          const result = await response.json();
          usernameAvailable = result.available;
        } catch (error) {
          console.error('Failed to check username:', error);
        } finally {
          checkingUsername = false;
        }
      }
    },
    500
  );
  
  function handleUsernameChange(value: string) {
    checkUsername({ username: value });
  }
  
  async function handleSubmit(data: any) {
    if (!usernameAvailable) {
      throw { details: { username: ['Username is not available'] } };
    }
    
    console.log('Form submitted:', data);
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
    type="text"
    required
    fullWidth
    bind:value={formContext.formData.username}
    error={formContext.errors.username || (!usernameAvailable ? 'Username is not available' : '')}
    onchange={(value) => {
      formContext.handleFieldChange('username', value);
      handleUsernameChange(value);
    }}
    onblur={() => formContext.handleFieldBlur('username', formContext.formData.username)}
  >
    {#snippet rightIcon()}
      {#if checkingUsername}
        <svg class="animate-spin h-4 w-4" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      {:else if formContext.formData.username && usernameAvailable}
        <svg class="h-4 w-4 text-success-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
        </svg>
      {/if}
    {/snippet}
  </FormField>
  
  <FormField
    name="email"
    label="Email Address"
    type="email"
    required
    fullWidth
    bind:value={formContext.formData.email}
    error={formContext.errors.email}
    onchange={(value) => formContext.handleFieldChange('email', value)}
    onblur={() => formContext.handleFieldBlur('email', formContext.formData.email)}
  />
  
  <FormField
    name="confirmEmail"
    label="Confirm Email Address"
    type="email"
    required
    fullWidth
    bind:value={formContext.formData.confirmEmail}
    error={formContext.errors.confirmEmail}
    onchange={(value) => formContext.handleFieldChange('confirmEmail', value)}
    onblur={() => formContext.handleFieldBlur('confirmEmail', formContext.formData.confirmEmail)}
  />
</FormWrapper>
`;