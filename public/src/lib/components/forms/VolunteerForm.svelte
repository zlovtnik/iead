<script lang="ts">
  import type { VolunteerFormData, VolunteerStatus } from '$lib/api/volunteers.js';
  import FormWrapper from './FormWrapper.svelte';
  import FormField from './FormField.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { volunteerSchema } from '$lib/validators/volunteer.js';
  import { members } from '$lib/stores/members.js';
  import { events } from '$lib/stores/events.js';
  import { onMount } from 'svelte';

  interface Props {
    initialData?: Partial<VolunteerFormData>;
    isEditing?: boolean;
    onSubmit: (data: VolunteerFormData) => Promise<void>;
    onCancel: () => void;
  }

  let { initialData = {}, isEditing = false, onSubmit, onCancel }: Props = $props();

  let formData = $state<Partial<VolunteerFormData>>({
    member_id: 0,
    event_id: undefined,
    role: '',
    hours: 0,
    notes: '',
    status: 'active' as VolunteerStatus,
    start_date: new Date().toISOString().split('T')[0],
    end_date: '',
    ...initialData
  });

  let validationErrors = $state<Record<string, string>>({});
  let isSubmitting = $state(false);

  // Load members and events on mount
  onMount(() => {
    members.loadMembers();
    events.loadEvents();
  });

  $effect(() => {
    if (initialData) {
      formData = { ...formData, ...initialData };
    }
  });

  const statusOptions = [
    { value: 'active', label: 'Active' },
    { value: 'inactive', label: 'Inactive' },
    { value: 'completed', label: 'Completed' }
  ];

  // Generate member options
  $: memberOptions = $members.members.map(member => ({
    value: member.id,
    label: member.name
  }));

  // Generate event options
  $: eventOptions = [
    { value: '', label: 'No specific event' },
    ...$events.events.map(event => ({
      value: event.id,
      label: event.title
    }))
  ];

  async function handleSubmit() {
    try {
      // Validate the form data
      const validatedData = volunteerSchema.parse({
        ...formData,
        member_id: Number(formData.member_id),
        event_id: formData.event_id ? Number(formData.event_id) : undefined,
        hours: Number(formData.hours) || 0
      });

      isSubmitting = true;
      validationErrors = {};

      await onSubmit(validatedData);
    } catch (error: any) {
      if (error.issues) {
        // Zod validation errors
        validationErrors = error.issues.reduce((acc: Record<string, string>, issue: any) => {
          const field = issue.path[0];
          acc[field] = issue.message;
          return acc;
        }, {});
      }
    } finally {
      isSubmitting = false;
    }
  }

  function handleCancel() {
    validationErrors = {};
    onCancel();
  }
</script>

<div class="bg-white p-6 rounded-lg shadow-sm border">
  <h2 class="text-xl font-semibold mb-6">
    {isEditing ? 'Edit Volunteer Assignment' : 'Create Volunteer Assignment'}
  </h2>

  <form on:submit|preventDefault={handleSubmit} class="space-y-6">
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <!-- Member Selection -->
      <FormField
        type="select"
        name="member_id"
        label="Member"
        options={memberOptions}
        bind:value={formData.member_id}
        error={validationErrors.member_id}
        required
      />

      <!-- Event Selection (Optional) -->
      <FormField
        type="select"
        name="event_id"
        label="Event (Optional)"
        options={eventOptions}
        bind:value={formData.event_id}
        error={validationErrors.event_id}
      />

      <!-- Role -->
      <FormField
        name="role"
        label="Role"
        bind:value={formData.role}
        error={validationErrors.role}
        placeholder="e.g., Usher, Greeter, Sound Tech"
        required
      />

      <!-- Status -->
      <FormField
        type="select"
        name="status"
        label="Status"
        options={statusOptions}
        bind:value={formData.status}
        error={validationErrors.status}
        required
      />

      <!-- Expected Hours -->
      <FormField
        type="number"
        name="hours"
        label="Expected Hours"
        bind:value={formData.hours}
        error={validationErrors.hours}
        placeholder="0"
        min={0}
        step={0.5}
      />

      <!-- Start Date -->
      <FormField
        type="date"
        name="start_date"
        label="Start Date"
        bind:value={formData.start_date}
        error={validationErrors.start_date}
        required
      />

      <!-- End Date (Optional) -->
      <FormField
        type="date"
        name="end_date"
        label="End Date (Optional)"
        bind:value={formData.end_date}
        error={validationErrors.end_date}
      />
    </div>

    <!-- Notes -->
    <FormField
      type="textarea"
      name="notes"
      label="Notes"
      bind:value={formData.notes}
      error={validationErrors.notes}
      placeholder="Additional notes about this volunteer assignment..."
      rows={4}
    />

    <!-- Form Actions -->
    <div class="flex justify-end space-x-3 pt-4 border-t">
      <Button
        type="button"
        variant="secondary"
        onclick={handleCancel}
        disabled={isSubmitting}
      >
        Cancel
      </Button>
      <Button
        type="submit"
        disabled={isSubmitting}
      >
        {isSubmitting ? 'Saving...' : (isEditing ? 'Update Assignment' : 'Create Assignment')}
      </Button>
    </div>
  </form>
</div>
