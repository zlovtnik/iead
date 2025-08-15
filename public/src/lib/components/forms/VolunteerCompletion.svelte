<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { Button, Modal } from '../ui/index.js';
  import { FormWrapper, FormField } from '../forms/index.js';
  import { volunteerCompletionSchema, type VolunteerCompletion } from '../../validators/volunteer.js';
  import { volunteers } from '../../stores/volunteers.js';
  import type { Volunteer } from '../../api/volunteers.js';

  interface Props {
    open?: boolean;
    volunteer?: Volunteer | null;
  }

  let {
    open = false,
    volunteer = null
  }: Props = $props();

  const dispatch = createEventDispatcher<{
    close: void;
    complete: Volunteer;
  }>();

  let isSubmitting = $state(false);
  let formData: VolunteerCompletion = $state({
    actual_hours: 0,
    completion_notes: ''
  });

  // Load initial data when form opens
  $effect(() => {
    if (open && volunteer) {
      loadFormData();
    }
  });

  function loadFormData() {
    if (volunteer) {
      formData = {
        actual_hours: volunteer.hours || 0,
        completion_notes: volunteer.notes || ''
      };
    }
  }

  async function handleComplete() {
    if (isSubmitting || !volunteer) return;

    isSubmitting = true;
    try {
      const completedVolunteer = await volunteers.completeVolunteerAssignment(volunteer.id, formData);
      dispatch('complete', completedVolunteer);
      handleClose();
    } catch (error) {
      console.error('Failed to complete volunteer assignment:', error);
    } finally {
      isSubmitting = false;
    }
  }

  function handleClose() {
    dispatch('close');
  }

  const estimatedHours = $derived(volunteer?.hours || 0);
  const actualHours = $derived(formData.actual_hours);
  const hoursDifference = $derived(actualHours - estimatedHours);
  const efficiencyRating = $derived(estimatedHours > 0 ? (actualHours / estimatedHours) * 100 : 100);
</script>

<Modal {open} size="md" title="Complete Volunteer Assignment" on:close={handleClose}>
  <div class="completion-form">
    {#if volunteer}
      <!-- Assignment Overview -->
      <div class="assignment-overview">
        <h3 class="overview-title">Assignment Details</h3>
        <div class="overview-grid">
          <div class="overview-item">
            <span class="label">Volunteer:</span>
            <span class="value">{volunteer.member_name || 'Unknown'}</span>
          </div>
          <div class="overview-item">
            <span class="label">Role:</span>
            <span class="value">{volunteer.role}</span>
          </div>
          <div class="overview-item">
            <span class="label">Event:</span>
            <span class="value">{volunteer.event_title || 'General Assignment'}</span>
          </div>
          <div class="overview-item">
            <span class="label">Start Date:</span>
            <span class="value">{new Date(volunteer.start_date).toLocaleDateString()}</span>
          </div>
          <div class="overview-item">
            <span class="label">Estimated Hours:</span>
            <span class="value">{estimatedHours} hours</span>
          </div>
          <div class="overview-item">
            <span class="label">Status:</span>
            <span class="status-badge status-{volunteer.status}">{volunteer.status.toUpperCase()}</span>
          </div>
        </div>
      </div>

      <FormWrapper
        schema={volunteerCompletionSchema}
        initialData={formData}
        onsubmit={handleComplete}
        submitText="Complete Assignment"
        disabled={isSubmitting}
      >
        <FormField name="actual_hours" label="Actual Hours Worked" required>
          <input
            type="number"
            bind:value={formData.actual_hours}
            min="0"
            step="0.5"
            required
            class="form-input"
          />
          <div class="hours-comparison">
            {#if hoursDifference !== 0}
              <small class="hours-diff" class:over={hoursDifference > 0} class:under={hoursDifference < 0}>
                {hoursDifference > 0 ? '+' : ''}{hoursDifference.toFixed(1)} hours vs. estimate
              </small>
            {/if}
            {#if estimatedHours > 0}
              <small class="efficiency">
                Efficiency: {efficiencyRating.toFixed(0)}%
                {#if efficiencyRating > 110}
                  (Over estimate)
                {:else if efficiencyRating < 90}
                  (Under estimate)
                {:else}
                  (On target)
                {/if}
              </small>
            {/if}
          </div>
        </FormField>

        <FormField name="completion_notes" label="Completion Notes">
          <textarea
            bind:value={formData.completion_notes}
            class="form-textarea"
            rows="4"
            placeholder="How did the assignment go? Any feedback, challenges, or highlights to note..."
          ></textarea>
        </FormField>

        <!-- Summary -->
        <div class="completion-summary">
          <h4 class="summary-title">Completion Summary</h4>
          <div class="summary-content">
            <p>
              <strong>{volunteer.member_name}</strong> completed their role as 
              <strong>{volunteer.role}</strong> and worked for 
              <strong>{actualHours} hours</strong>.
            </p>
            {#if hoursDifference > 0}
              <p class="text-orange-600">
                ⚠️ Worked {hoursDifference.toFixed(1)} hours more than estimated.
              </p>
            {:else if hoursDifference < 0}
              <p class="text-green-600">
                ✅ Completed {Math.abs(hoursDifference).toFixed(1)} hours under estimate.
              </p>
            {:else}
              <p class="text-blue-600">
                🎯 Completed exactly as estimated.
              </p>
            {/if}
          </div>
        </div>
      </FormWrapper>
    {:else}
      <p class="no-volunteer">No volunteer assignment selected.</p>
    {/if}
  </div>
</Modal>

<style>
  .completion-form {
    padding: 1rem;
  }

  .assignment-overview {
    margin-bottom: 1.5rem;
    padding: 1rem;
    background-color: #f8fafc;
    border-radius: 0.5rem;
    border: 1px solid #e2e8f0;
  }

  .overview-title {
    font-size: 1rem;
    font-weight: 600;
    margin-bottom: 0.75rem;
    color: #374151;
  }

  .overview-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 0.5rem;
  }

  .overview-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .label {
    font-weight: 500;
    color: #6b7280;
  }

  .value {
    color: #111827;
    font-weight: 500;
  }

  .status-badge {
    padding: 0.25rem 0.5rem;
    border-radius: 0.25rem;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
  }

  .status-active {
    background-color: #dbeafe;
    color: #1d4ed8;
  }

  .status-inactive {
    background-color: #f3f4f6;
    color: #6b7280;
  }

  .status-completed {
    background-color: #dcfce7;
    color: #16a34a;
  }

  .form-input {
    width: 100%;
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    background-color: white;
    font-size: 0.875rem;
  }

  .form-input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .form-textarea {
    width: 100%;
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    background-color: white;
    font-size: 0.875rem;
    font-family: inherit;
    resize: vertical;
  }

  .form-textarea:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .form-textarea::placeholder {
    color: #9ca3af;
  }

  .hours-comparison {
    margin-top: 0.5rem;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .hours-diff {
    font-size: 0.75rem;
    font-weight: 500;
  }

  .hours-diff.over {
    color: #dc2626;
  }

  .hours-diff.under {
    color: #16a34a;
  }

  .efficiency {
    font-size: 0.75rem;
    color: #6b7280;
  }

  .completion-summary {
    margin-top: 1.5rem;
    padding: 1rem;
    background-color: #f9fafb;
    border-radius: 0.5rem;
    border: 1px solid #e5e7eb;
  }

  .summary-title {
    font-size: 0.875rem;
    font-weight: 600;
    margin-bottom: 0.5rem;
    color: #374151;
  }

  .summary-content p {
    margin: 0.5rem 0;
    color: #4b5563;
  }

  .summary-content strong {
    color: #111827;
    font-weight: 600;
  }

  .text-orange-600 {
    color: #ea580c;
  }

  .text-green-600 {
    color: #16a34a;
  }

  .text-blue-600 {
    color: #2563eb;
  }

  .no-volunteer {
    text-align: center;
    color: #6b7280;
    padding: 2rem;
  }
</style>
