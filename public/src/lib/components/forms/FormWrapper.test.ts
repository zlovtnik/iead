import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import { z } from 'zod';
import FormWrapper from './FormWrapper.svelte';
import FormField from './FormField.svelte';

// Test schema
const testSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  email: z.string().email('Invalid email'),
  age: z.number().min(18, 'Must be at least 18'),
});

type TestData = z.infer<typeof testSchema>;

// Test component that uses FormWrapper
const TestForm = `
<script>
  import FormWrapper from './FormWrapper.svelte';
  import FormField from './FormField.svelte';
  
  export let schema;
  export let onsubmit;
  export let initialData = {};
</script>

<FormWrapper {schema} {onsubmit} {initialData} let:formContext>
  <FormField
    name="name"
    label="Name"
    type="text"
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
  
  <FormField
    name="age"
    label="Age"
    type="number"
    required
    bind:value={formContext.formData.age}
    error={formContext.errors.age}
    onchange={(value) => formContext.handleFieldChange('age', value)}
    onblur={() => formContext.handleFieldBlur('age', formContext.formData.age)}
  />
</FormWrapper>
`;

describe('FormWrapper', () => {
  let mockSubmit: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    mockSubmit = vi.fn();
  });

  it('renders form with initial data', () => {
    const initialData = { name: 'John Doe', email: 'john@example.com', age: 25 };
    
    render(TestForm, {
      props: {
        schema: testSchema,
        onsubmit: mockSubmit,
        initialData
      }
    });

    expect(screen.getByDisplayValue('John Doe')).toBeInTheDocument();
    expect(screen.getByDisplayValue('john@example.com')).toBeInTheDocument();
    expect(screen.getByDisplayValue('25')).toBeInTheDocument();
  });

  it('validates form on submit', async () => {
    render(TestForm, {
      props: {
        schema: testSchema,
        onsubmit: mockSubmit
      }
    });

    const submitButton = screen.getByRole('button', { name: /submit/i });
    await fireEvent.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText('Name is required')).toBeInTheDocument();
      expect(screen.getByText('Invalid email')).toBeInTheDocument();
    });

    expect(mockSubmit).not.toHaveBeenCalled();
  });

  it('submits valid form data', async () => {
    render(TestForm, {
      props: {
        schema: testSchema,
        onsubmit: mockSubmit
      }
    });

    const nameInput = screen.getByLabelText(/name/i);
    const emailInput = screen.getByLabelText(/email/i);
    const ageInput = screen.getByLabelText(/age/i);
    const submitButton = screen.getByRole('button', { name: /submit/i });

    await fireEvent.input(nameInput, { target: { value: 'John Doe' } });
    await fireEvent.input(emailInput, { target: { value: 'john@example.com' } });
    await fireEvent.input(ageInput, { target: { value: '25' } });

    await fireEvent.click(submitButton);

    await waitFor(() => {
      expect(mockSubmit).toHaveBeenCalledWith({
        name: 'John Doe',
        email: 'john@example.com',
        age: 25
      });
    });
  });

  it('handles submission errors', async () => {
    const errorSubmit = vi.fn().mockRejectedValue({
      message: 'Server error',
      details: { email: ['Email already exists'] }
    });

    render(TestForm, {
      props: {
        schema: testSchema,
        onsubmit: errorSubmit,
        initialData: { name: 'John', email: 'john@example.com', age: 25 }
      }
    });

    const submitButton = screen.getByRole('button', { name: /submit/i });
    await fireEvent.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText('Email already exists')).toBeInTheDocument();
    });
  });

  it('shows loading state during submission', async () => {
    const slowSubmit = vi.fn().mockImplementation(() => 
      new Promise(resolve => setTimeout(resolve, 100))
    );

    render(TestForm, {
      props: {
        schema: testSchema,
        onsubmit: slowSubmit,
        initialData: { name: 'John', email: 'john@example.com', age: 25 }
      }
    });

    const submitButton = screen.getByRole('button', { name: /submit/i });
    await fireEvent.click(submitButton);

    expect(screen.getByText(/loading/i)).toBeInTheDocument();
    expect(submitButton).toBeDisabled();

    await waitFor(() => {
      expect(screen.queryByText(/loading/i)).not.toBeInTheDocument();
    });
  });

  it('resets form when resetOnSubmit is true', async () => {
    render(TestForm, {
      props: {
        schema: testSchema,
        onsubmit: mockSubmit,
        resetOnSubmit: true
      }
    });

    const nameInput = screen.getByLabelText(/name/i);
    const submitButton = screen.getByRole('button', { name: /submit/i });

    await fireEvent.input(nameInput, { target: { value: 'John Doe' } });
    await fireEvent.input(screen.getByLabelText(/email/i), { target: { value: 'john@example.com' } });
    await fireEvent.input(screen.getByLabelText(/age/i), { target: { value: '25' } });

    await fireEvent.click(submitButton);

    await waitFor(() => {
      expect(nameInput).toHaveValue('');
    });
  });

  it('validates fields on blur when enabled', async () => {
    render(TestForm, {
      props: {
        schema: testSchema,
        onsubmit: mockSubmit,
        validateOnBlur: true
      }
    });

    const emailInput = screen.getByLabelText(/email/i);
    
    // First submit to enable validation
    await fireEvent.click(screen.getByRole('button', { name: /submit/i }));
    
    await fireEvent.input(emailInput, { target: { value: 'invalid-email' } });
    await fireEvent.blur(emailInput);

    await waitFor(() => {
      expect(screen.getByText('Invalid email')).toBeInTheDocument();
    });
  });
});