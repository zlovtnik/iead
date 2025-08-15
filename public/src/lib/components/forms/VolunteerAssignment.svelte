<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { Button, Modal } from '../ui/index.js';
  import { FormWrapper, FormField } from '../forms/index.js';
  import { volunteerAssignmentSchema, type VolunteerAssignment } from '../../validators/volunteer.js';
  import { members } from '../../stores/members.js';
  import { events } from '../../stores/events.js';
  import { volunteers } from '../../stores/volunteers.js';
  import { get } from 'svelte/store';
  import type { Volunteer } from '../../api/volunteers.js';

  interface Props {
    open?: boolean;
    eventId?: number | null;
    memberId?: number | null;
  }

  let {
    open = false,
    eventId = null,
    memberId = null
  }: Props = $props();

  const dispatch = createEventDispatcher<{
    close: void;
    assign: Volunteer;
  }>();

  let isSubmitting = $state(false);
  let formData: VolunteerAssignment = $state({
    member_id: memberId || 0,
    event_id: eventId || 0,
    role: '',
    expected_hours: undefined,
    notes: ''
  });

  // Available volunteer roles
  const defaultRoles = [
    'Event Coordinator',
    'Setup Team',
    'Cleanup Crew',
    'Usher',
    'Greeter',
    'Audio/Visual Tech',
    'Childcare',
    'Kitchen Helper',
    'Security',
    'Parking Attendant',
    'Translation',
    'Music Ministry',
    'Prayer Team',
    'General Helper'
  ];

  // Load initial data when form opens
  $effect(() => {
    if (open) {
      loadFormData();
      loadOptions();
    }
  });

  function loadFormData() {
    formData = {
      member_id: memberId || 0,
      event_id: eventId || 0,
      role: '',
      expected_hours: undefined,
      notes: ''
    };
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

      // Load volunteer roles if available
      await volunteers.loadVolunteerRoles().catch(() => {
        // Fallback to default roles if API call fails
        console.log('Using default volunteer roles');
      });
    } catch (error) {
      console.error('Failed to load form options:', error);
    }
  }

  async function handleAssign() {
    if (isSubmitting) return;

    isSubmitting = true;
    try {
      const assignedVolunteer = await volunteers.assignVolunteerToEvent(formData);
      dispatch('assign', assignedVolunteer);
      handleClose();
    } catch (error) {
      console.error('Failed to assign volunteer:', error);
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

  const availableRoles = $derived($volunteers.availableRoles.length > 0 
    ? $volunteers.availableRoles 
    : defaultRoles);

  const rolesOptions = $derived(availableRoles.map(role => ({
    value: role,
    label: role
  })));

  const selectedEvent = $derived(eventId 
    ? $events.events.find(e => e.id === eventId)
    : $events.events.find(e => e.id === formData.event_id));

  const selectedMember = $derived(memberId 
    ? $members.members.find(m => m.id === memberId)
    : $members.members.find(m => m.id === formData.member_id));
</script>

<Modal {open} size="lg" title="Assign Volunteer to Event" on:close={handleClose}>
  <div class="assignment-form">
    <FormWrapper
      schema={volunteerAssignmentSchema}
      initialData={formData}
      onsubmit={handleAssign}
      submitText="Assign Volunteer"
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
          {#if selectedMember}
            <div class="member-info">
              <small class="text-gray-600">
                {selectedMember.email}
                {#if selectedMember.phone}
                  • {selectedMember.phone}
                {/if}
              </small>
            </div>
          {/if}
        </FormField>

        <FormField name="event_id" label="Event" required>
          <select
            bind:value={formData.event_id}
            class="form-select"
            required
            disabled={!!eventId}
          >
            <option value={0}>Select an event...</option>
            {#each eventsOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
          {#if selectedEvent}
            <div class="event-info">
              <small class="text-gray-600">
                {new Date(selectedEvent.start_date).toLocaleDateString()}
                {#if selectedEvent.location}
                  • {selectedEvent.location}
                {/if}
              </small>
            </div>
          {/if}
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

        <FormField name="expected_hours" label="Expected Hours">
          <input
            type="number"
            bind:value={formData.expected_hours}
            min="0"
            step="0.5"
            placeholder="0"
            class="form-input"
          />
        </FormField>
      </div>

      <FormField name="notes" label="Assignment Notes">
        <textarea
          bind:value={formData.notes}
          class="form-textarea"
          rows="3"
          placeholder="Any specific instructions or notes for this assignment..."
        ></textarea>
      </FormField>

      <!-- Assignment Summary -->
      {#if formData.member_id && formData.event_id && formData.role}
        <div class="assignment-summary">
          <h3 class="summary-title">Assignment Summary</h3>
          <div class="summary-content">
            <p>
              <strong>{selectedMember?.name || 'Selected Member'}</strong> 
              will be assigned as 
              <strong>{formData.role}</strong> 
              for 
              <strong>{selectedEvent?.title || 'Selected Event'}</strong>
            </p>
            {#if formData.expected_hours}
              <p>Expected time commitment: <strong>{formData.expected_hours} hours</strong></p>
            {/if}
            {#if selectedEvent}
              <p>Event date: <strong>{new Date(selectedEvent.start_date).toLocaleDateString()}</strong></p>
            {/if}
          </div>
        </div>
      {/if}
    </FormWrapper>
  </div>
</Modal>

<style>
  .assignment-form {
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

  .member-info,
  .event-info {
    margin-top: 0.25rem;
  }

  .text-gray-600 {
    color: #6b7280;
  }

  .assignment-summary {
    margin-top: 1.5rem;
    padding: 1rem;
    background-color: #f9fafb;
    border-radius: 0.5rem;
    border: 1px solid #e5e7eb;
  }

  .summary-title {
    font-size: 1rem;
    font-weight: 600;
    margin-bottom: 0.5rem;
    color: #374151;
  }

  .summary-content p {
    margin: 0.25rem 0;
    color: #4b5563;
  }

  .summary-content strong {
    color: #111827;
    font-weight: 600;
  }
</style>
