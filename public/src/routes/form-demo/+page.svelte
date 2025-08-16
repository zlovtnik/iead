<script lang="ts">
  import { FormWrapper, FormField } from '$lib/components/forms';
  import { memberSchema, type Member } from '$lib/validators/member.js';
  
  let initialData: Partial<Member> = {
    name: '',
    email: '',
    phone: '',
    salary: undefined
  };
  
  async function handleSubmit(data: Member) {
    console.log('Form submitted with data:', data);
    
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Simulate success
    alert('Member created successfully!');
  }
</script>

<svelte:head>
  <title>Form System Demo</title>
</svelte:head>

<div class="max-w-2xl mx-auto p-6">
  <h1 class="text-3xl font-bold text-secondary-900 mb-8">Form System Demo</h1>
  
  <div class="bg-white rounded-lg shadow-md p-6">
    <h2 class="text-xl font-semibold text-secondary-800 mb-6">Create New Member</h2>
    
    <FormWrapper
      schema={memberSchema}
      {initialData}
      onsubmit={handleSubmit}
      submitText="Create Member"
      resetOnSubmit={true}
      validateOnBlur={true}
      let:formContext
    >
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
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
          placeholder="Enter full name"
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
          placeholder="Enter email address"
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
          placeholder="Enter phone number"
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
          placeholder="Enter annual salary"
          helperText="Used for tithe calculations"
          min="0"
          step="0.01"
        />
      </div>
    </FormWrapper>
  </div>
  
  <div class="mt-8 bg-secondary-50 rounded-lg p-6">
    <h3 class="text-lg font-semibold text-secondary-800 mb-4">Form Features Demonstrated:</h3>
    <ul class="list-disc list-inside space-y-2 text-secondary-700">
      <li>Zod schema validation with custom error messages</li>
      <li>Real-time validation on blur</li>
      <li>Form submission with loading states</li>
      <li>Error handling and display</li>
      <li>Form reset after successful submission</li>
      <li>Accessible form fields with proper ARIA attributes</li>
      <li>Responsive grid layout</li>
      <li>Helper text and placeholder support</li>
    </ul>
  </div>
</div>