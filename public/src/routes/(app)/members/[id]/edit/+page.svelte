<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { members, type Member } from '$lib/stores/members.js';
  import { memberUpdateSchema } from '$lib/validators/member.js';
  import FormWrapper from '$lib/components/forms/FormWrapper.svelte';
  import FormField from '$lib/components/forms/FormField.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Loading from '$lib/components/ui/Loading.svelte';
  import type { MemberFormData } from '$lib/api/members.js';

  let memberId = $derived(parseInt($page.params.id));
  let member: Member | null = $state(null);
  let isLoading = $state(true);
  let isSubmitting = $state(false);
  let error = $state<string | null>(null);

  // Subscribe to members store
  members.subscribe((state) => {
    if (state.selectedMember && state.selectedMember.id === memberId) {
      member = state.selectedMember;
    }
    error = state.error;
    isLoading = state.isLoading;
    isSubmitting = state.isUpdating;
  });

  async function loadMember() {
    try {
      isLoading = true;
      member = await members.loadMember(memberId);
    } catch (err) {
      console.error('Failed to load member:', err);
      error = 'Failed to load member details';
    } finally {
      isLoading = false;
    }
  }

  async function handleSubmit(data: MemberFormData) {
    if (!member) return;
    
    try {
      const updatedMember = await members.updateMember(member.id, data);
      // Redirect to the member's detail page
      await goto(`/members/${updatedMember.id}`);
    } catch (error) {
      console.error('Failed to update member:', error);
      // Error is handled by FormWrapper
    }
  }

  function handleCancel() {
    if (member) {
      goto(`/members/${member.id}`);
    } else {
      goto('/members');
    }
  }

  onMount(() => {
    loadMember();
  });

  // Prepare initial form data
  const initialData = $derived<Partial<MemberFormData>>(() => {
    if (!member) return {};
    
    return {
      name: member.name || '',
      email: member.email || '',
      phone: member.phone || '',
      salary: member.salary || undefined
    };
  });
</script>

<svelte:head>
  <title>Edit {member?.name || 'Member'} - Church Management</title>
</svelte:head>

<div class="max-w-2xl mx-auto space-y-6">
  <!-- Header -->
  <div class="flex items-center justify-between">
    <div>
      <div class="flex items-center space-x-2 text-sm text-gray-500 mb-2">
        <button
          onclick={() => goto('/members')}
          class="hover:text-gray-700 transition-colors"
        >
          Members
        </button>
        <span>›</span>
        {#if member}
          <button
            onclick={() => goto(`/members/${member.id}`)}
            class="hover:text-gray-700 transition-colors"
          >
            {member.name}
          </button>
          <span>›</span>
        {/if}
        <span>Edit</span>
      </div>
      
      <h1 class="text-2xl font-bold text-gray-900">
        Edit {member?.name || 'Member'}
      </h1>
      <p class="text-gray-600">Update member information and details</p>
    </div>
    
    <Button
      variant="outline"
      onclick={handleCancel}
      disabled={isSubmitting}
    >
      Cancel
    </Button>
  </div>

  {#if isLoading}
    <div class="flex justify-center py-12">
      <Loading />
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-4">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm text-red-800">{error}</p>
        </div>
      </div>
    </div>
  {:else if member}
    <!-- Form -->
    <div class="bg-white rounded-lg shadow p-6">
      <FormWrapper
        schema={memberUpdateSchema}
        initialData={initialData}
        onsubmit={handleSubmit}
        submitText="Update Member"
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

            <!-- Member History -->
            <div>
              <h3 class="text-lg font-medium text-gray-900 mb-4">Member Information</h3>
              <div class="bg-gray-50 rounded-lg p-4">
                <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Member Since</dt>
                    <dd class="mt-1 text-sm text-gray-900">
                      {new Date(member.created_at).toLocaleDateString()}
                    </dd>
                  </div>
                  
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Member ID</dt>
                    <dd class="mt-1 text-sm text-gray-900">#{member.id}</dd>
                  </div>
                </dl>
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
                Update Member
              </Button>
            </div>
          </div>
        {/snippet}
      </FormWrapper>
    </div>
  {:else}
    <div class="text-center py-12">
      <p class="text-gray-500">Member not found</p>
      <Button
        variant="outline"
        onclick={() => goto('/members')}
        class="mt-4"
      >
        Back to Members
      </Button>
    </div>
  {/if}
</div>