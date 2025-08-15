<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { Button, Input, Modal, Loading } from '../ui/index.js';
  import { FormWrapper, FormField } from '../forms/index.js';
  import { volunteerSchema, type VolunteerFormData } from '../../validators/volunteer.js';
  import { members } from '../../stores/members.js';
  import { events } from '../../stores/events.js';
  import { volunteers } from '../../stores/volunteers.js';
  import { get } from 'svelte/store';
  import type { Volunteer } from '../../api/volunteers.js';

  interface Props {
    open?: boolean;
    volunteer?: Volunteer | null;
    memberId?: number | null;
    eventId?: number | null;
  }

  let {
    open = false,
    volunteer = null,
    memberId = null,
    eventId = null
  }: Props = $props();

  const dispatch = createEventDispatcher<{
    close: void;
    submit: Volunteer;
  }>();

  let isSubmitting = $state(false);
  let formData: VolunteerFormData = $state({
    member_id: memberId || 0,
    event_id: eventId || undefined,
    role: '',
    hours: 0,
    notes: '',
    status: 'active',
    start_date: new Date().toISOString().split('T')[0],
    end_date: undefined
  });

  // Load initial data when form opens
  $effect(() => {
    if (open) {
      loadFormData();
      loadOptions();
    }
  });

  function loadFormData() {
    if (volunteer) {
      formData = {
        member_id: volunteer.member_id,
        event_id: volunteer.event_id,
        role: volunteer.role,
        hours: volunteer.hours,
        notes: volunteer.notes || '',
        status: volunteer.status,
        start_date: volunteer.start_date.split('T')[0],
        end_date: volunteer.end_date?.split('T')[0]
      };
    } else {
      formData = {
        member_id: memberId || 0,
        event_id: eventId || undefined,
        role: '',
        hours: 0,
        notes: '',
        status: 'active',
        start_date: new Date().toISOString().split('T')[0],
        end_date: undefined
      };
    }
  }

  async function loadOptions() {
    try {
      // Load members if not already loaded
      const membersState = get(members);
      if (membersState.members.length === 0) {
        await members.loadMembers();
      }

      // Load events if not already loaded
      const eventsState = get(events);
      if (eventsState.events.length === 0) {
        await events.loadEvents();
      }

      // Load volunteer roles
      await volunteers.loadVolunteerRoles();
    } catch (error) {
      console.error('Failed to load form options:', error);
    }
  }

  async function handleSubmit() {
    if (isSubmitting) return;

    isSubmitting = true;
    try {
      let savedVolunteer: Volunteer;
      
      if (volunteer) {
        savedVolunteer = await volunteers.updateVolunteer(volunteer.id, formData);
      } else {
        savedVolunteer = await volunteers.createVolunteer(formData);
      }

      dispatch('submit', savedVolunteer);
      handleClose();
    } catch (error) {
      console.error('Failed to save volunteer:', error);
    } finally {
      isSubmitting = false;
    }
  }

  function handleClose() {
    dispatch('close');
  }

  // Computed values
  const membersOptions = $derived($members.members.map(member => ({
    value: member.id,
    label: member.name
  })));

  const eventsOptions = $derived($events.events.map(event => ({
    value: event.id,
    label: event.title
  })));

  const rolesOptions = $derived($volunteers.availableRoles.map(role => ({
    value: role,
    label: role
  })));

  const modalTitle = $derived(volunteer ? 'Edit Volunteer Assignment' : 'Create Volunteer Assignment');
</script>

<Modal {open} size="lg" title={modalTitle} on:close={handleClose}>
  <div class="volunteer-form">
    <FormWrapper
      schema={volunteerSchema}
      initialData={formData}
      onsubmit={handleSubmit}
      submitText={volunteer ? 'Update Assignment' : 'Create Assignment'}
      disabled={isSubmitting}
    >
      <div class="form-grid">
        <FormField name="member_id" label="Member" required>
          <select
            bind:value={formData.member_id}
            class="form-select"
            required
            disabled={!!memberId}
          >
            <option value={0}>Select a member...</option>
            {#each membersOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </FormField>

        <FormField name="event_id" label="Event (Optional)">
          <select
            bind:value={formData.event_id}
            class="form-select"
            disabled={!!eventId}
          >
            <option value={undefined}>No specific event</option>
            {#each eventsOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </FormField>

        <FormField name="role" label="Volunteer Role" required>
          <select
            bind:value={formData.role}
            class="form-select"
            required
          >
            <option value="">Select a role...</option>
            {#each rolesOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </FormField>

        <FormField name="status" label="Status" required>
          <select
            bind:value={formData.status}
            class="form-select"
            required
          >
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
            <option value="completed">Completed</option>
          </select>
        </FormField>

        <FormField name="hours" label="Hours">
          <input
            type="number"
            bind:value={formData.hours}
            min="0"
            step="0.5"
            placeholder="0"
            class="form-input"
          />
        </FormField>

        <FormField name="start_date" label="Start Date" required>
          <input
            type="date"
            bind:value={formData.start_date}
            required
            class="form-input"
          />
        </FormField>

        <FormField name="end_date" label="End Date (Optional)">
          <input
            type="date"
            bind:value={formData.end_date}
            min={formData.start_date}
            class="form-input"
          />
        </FormField>
      </div>

      <FormField name="notes" label="Notes">
        <textarea
          bind:value={formData.notes}
          class="form-textarea"
          rows="3"
          placeholder="Additional notes about this volunteer assignment..."
        ></textarea>
      </FormField>
    </FormWrapper>
  </div>
</Modal>

<style>
  .volunteer-form {
    padding: 1rem;
  }

  .form-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .form-select {
    width: 100%;
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    background-color: white;
    font-size: 0.875rem;
  }

  .form-select:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .form-select:disabled {
    background-color: #f9fafb;
    color: #6b7280;
    cursor: not-allowed;
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
</style>
