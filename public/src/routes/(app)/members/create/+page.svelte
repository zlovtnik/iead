<script lang="ts">
  import { goto } from '$app/navigation';
  import { members } from '$lib/stores/members.js';
  import { memberCreateSchema } from '$lib/validators/member.js';
  import FormWrapper from '$lib/components/forms/FormWrapper.svelte';
  import FormField from '$lib/components/forms/FormField.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import type { MemberFormData } from '$lib/api/members.js';

  let isSubmitting = $state(false);

  const initialData: Partial<MemberFormData> = {
    name: '',
    email: '',
    phone: '',
    salary: undefined
  };

  async function handleSubmit(data: MemberFormData) {
    isSubmitting = true;
    try {
      const newMember = await members.createMember(data);
      // Redirect to the new member's detail page
      await goto(`/members/${newMember.id}`);
    } catch (error) {
      console.error('Failed to create member:', error);
      // Error is handled by FormWrapper
    } finally {
      isSubmitting = false;
    }
  }

  function handleCancel() {
    goto('/members');
  }
</script>

<svelte:head>
  <title>Create Member - Church Management</title>
</svelte:head>

<div class="max-w-2xl mx-auto space-y-6">
  <!-- Header -->
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Create New Member</h1>
      <p class="text-gray-600">Add a new member to the church directory</p>
    </div>
    
    <Button
      variant="outline"
      onclick={handleCancel}
      disabled={isSubmitting}
    >
      Cancel
    </Button>
  </div>

  <!-- Form -->
  <div class="bg-white rounded-lg shadow p-6">
    <FormWrapper
      schema={memberCreateSchema}
      initialData={initialData}
      onsubmit={handleSubmit}
      submitText="Create Member"
      submitVariant="primary"
      disabled={isSubmitting}
    >
      {#snippet children(form)}
        <div class="space-y-6">
          <!-- Basic Information -->
          <div>
            <h3 class="text-lg font-medium text-gray-900 mb-4">Basic Information</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="md:col-span-2">
                <FormField
                  name="name"
                  label="Full Name"
                  type="text"
                  required
                  placeholder="Enter member's full name"
                  bind:value={form.formData.name}
                  error={form.errors.name}
                  onchange={(value) => form.handleFieldChange('name', value)}
                  onblur={(e) => form.handleFieldBlur('name', e.target.value)}
                  fullWidth
                />
              </div>
              
              <FormField
                name="email"
                label="Email Address"
                type="email"
                required
                placeholder="member@example.com"
                bind:value={form.formData.email}
                error={form.errors.email}
                onchange={(value) => form.handleFieldChange('email', value)}
                onblur={(e) => form.handleFieldBlur('email', e.target.value)}
                fullWidth
              />
              
              <FormField
                name="phone"
                label="Phone Number"
                type="tel"
                placeholder="(555) 123-4567"
                bind:value={form.formData.phone}
                error={form.errors.phone}
                onchange={(value) => form.handleFieldChange('phone', value)}
                onblur={(e) => form.handleFieldBlur('phone', e.target.value)}
                helperText="Optional - Include area code"
                fullWidth
              />
            </div>
          </div>

          <!-- Financial Information -->
          <div>
            <h3 class="text-lg font-medium text-gray-900 mb-4">Financial Information</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormField
                name="salary"
                label="Annual Salary"
                type="number"
                placeholder="50000"
                bind:value={form.formData.salary}
                error={form.errors.salary}
                onchange={(value) => form.handleFieldChange('salary', value)}
                onblur={(e) => form.handleFieldBlur('salary', parseFloat(e.target.value) || undefined)}
                helperText="Optional - Used for tithe calculations"
                min="0"
                step="1000"
                fullWidth
              />
            </div>
          </div>

          <!-- Form Actions -->
          <div class="flex justify-end space-x-3 pt-6 border-t border-gray-200">
            <Button
              type="button"
              variant="outline"
              onclick={handleCancel}
              disabled={isSubmitting}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              variant="primary"
              loading={isSubmitting}
              disabled={isSubmitting}
            >
              Create Member
            </Button>
          </div>
        </div>
      {/snippet}
    </FormWrapper>
  </div>
</div>