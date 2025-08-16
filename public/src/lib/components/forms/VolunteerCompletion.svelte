<script lang="ts">
  import Button from '$lib/components/ui/Button.svelte';
  import FormField from './FormField.svelte';
  import type { Volunteer } from '$lib/api/volunteers.js';

  interface Props {
    volunteer: Volunteer;
    onSubmit: (data: { actualHours: number; notes?: string }) => Promise<void>;
    onCancel: () => void;
  }

  let { volunteer, onSubmit, onCancel }: Props = $props();

  let actualHours = $state(volunteer.hours || 0);
  let completionNotes = $state('');
  let isSubmitting = $state(false);
  let validationErrors = $state<Record<string, string>>({});

  // Calculate efficiency
  let efficiency = $derived(volunteer.hours > 0 ? (actualHours / volunteer.hours) * 100 : 100);
  let efficiencyColor = $derived(efficiency <= 100 ? 'text-green-600' : efficiency <= 120 ? 'text-yellow-600' : 'text-red-600');

  async function handleSubmit() {
    try {
      validationErrors = {};
      
      // Basic validation
      if (actualHours < 0) {
        validationErrors.actualHours = 'Actual hours cannot be negative';
        return;
      }

      isSubmitting = true;
      await onSubmit({
        actualHours,
        notes: completionNotes || undefined
      });
    } catch (error) {
      console.error('Failed to complete volunteer assignment:', error);
    } finally {
      isSubmitting = false;
    }
  }

  function handleCancel() {
    validationErrors = {};
    onCancel();
  }
</script>

<div class="bg-white p-6 rounded-lg">
  <h3 class="text-lg font-semibold mb-6">Complete Volunteer Assignment</h3>

  <!-- Volunteer Details -->
  <div class="bg-gray-50 p-4 rounded-lg mb-6">
    <h4 class="font-medium text-gray-900 mb-2">Assignment Details</h4>
    <div class="grid grid-cols-2 gap-4 text-sm">
      <div>
        <span class="font-medium">Role:</span> {volunteer.role}
      </div>
      <div>
        <span class="font-medium">Expected Hours:</span> {volunteer.hours}
      </div>
      <div>
        <span class="font-medium">Start Date:</span> {new Date(volunteer.start_date).toLocaleDateString()}
      </div>
      <div>
        <span class="font-medium">Status:</span> 
        <span class="px-2 py-1 rounded text-xs bg-yellow-100 text-yellow-800">{volunteer.status}</span>
      </div>
    </div>
    {#if volunteer.notes}
      <div class="mt-2 text-sm">
        <span class="font-medium">Notes:</span> {volunteer.notes}
      </div>
    {/if}
  </div>

  <form on:submit|preventDefault={handleSubmit} class="space-y-6">
    <!-- Actual Hours -->
    <FormField
      name="actual_hours"
      label="Actual Hours Worked"
      type="number"
      bind:value={actualHours}
      error={validationErrors.actualHours}
      min={0}
      step={0.5}
      required
    />

    <!-- Efficiency Indicator -->
    <div class="bg-blue-50 p-4 rounded-lg">
      <div class="flex justify-between items-center">
        <span class="text-sm font-medium text-gray-700">Efficiency</span>
        <span class="text-lg font-bold {efficiencyColor}">
          {efficiency.toFixed(1)}%
        </span>
      </div>
      <div class="mt-2 text-xs text-gray-600">
        {#if efficiency <= 100}
          Completed efficiently within expected time
        {:else if efficiency <= 120}
          Slightly over expected time
        {:else}
          Significantly over expected time
        {/if}
      </div>
    </div>

    <!-- Completion Notes -->
    <FormField
      name="completion_notes"
      label="Completion Notes (Optional)"
      type="textarea"
      bind:value={completionNotes}
      placeholder="Add any notes about the completion of this assignment..."
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
        {isSubmitting ? 'Completing...' : 'Complete Assignment'}
      </Button>
    </div>
  </form>
</div>
