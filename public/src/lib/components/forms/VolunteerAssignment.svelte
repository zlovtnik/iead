<script lang="ts">
  import type { Volunteer } from '$lib/api/volunteers.js';
  import type { Event } from '$lib/api/events.js';
  import type { Member } from '$lib/api/members.js';
  import Button from '$lib/components/ui/Button.svelte';
  import Modal from '$lib/components/ui/Modal.svelte';
  import VolunteerForm from './VolunteerForm.svelte';
  import { volunteers } from '$lib/stores/volunteers.js';
  import { events } from '$lib/stores/events.js';
  import { members } from '$lib/stores/members.js';
  import { onMount } from 'svelte';

  interface Props {
    eventId?: number;
    selectedEvent?: Event;
    isOpen?: boolean;
    onClose?: () => void;
  }

  let { eventId, selectedEvent, isOpen = false, onClose }: Props = $props();

  let showVolunteerForm = $state(false);
  let selectedVolunteer = $state<Volunteer | null>(null);
  let eventVolunteers = $state<Volunteer[]>([]);
  let availableMembers = $state<Member[]>([]);
  let loading = $state(false);

  // Load data on mount
  onMount(() => {
    if (eventId || selectedEvent?.id) {
      loadEventVolunteers();
    }
    loadAvailableMembers();
  });

  // Watch for changes in eventId
  $effect(() => {
    if (eventId || selectedEvent?.id) {
      loadEventVolunteers();
    }
  });

  async function loadEventVolunteers() {
    if (!eventId && !selectedEvent?.id) return;
    
    loading = true;
    try {
      const id = eventId || selectedEvent!.id;
      const volunteers = await import('$lib/api/volunteers.js');
      eventVolunteers = await volunteers.VolunteersApi.getVolunteersByEvent(id);
    } catch (error) {
      console.error('Failed to load event volunteers:', error);
    } finally {
      loading = false;
    }
  }

  async function loadAvailableMembers() {
    try {
      await members.loadMembers();
      availableMembers = $members.members;
    } catch (error) {
      console.error('Failed to load members:', error);
    }
  }

  function handleCreateAssignment() {
    selectedVolunteer = null;
    showVolunteerForm = true;
  }

  function handleEditVolunteer(volunteer: Volunteer) {
    selectedVolunteer = volunteer;
    showVolunteerForm = true;
  }

  async function handleFormSubmit(data: any) {
    try {
      if (selectedVolunteer) {
        await volunteers.updateVolunteer(selectedVolunteer.id, data);
      } else {
        await volunteers.createVolunteer({
          ...data,
          event_id: eventId || selectedEvent?.id
        });
      }
      
      showVolunteerForm = false;
      selectedVolunteer = null;
      await loadEventVolunteers();
    } catch (error) {
      // Error handling is done in the store
    }
  }

  function handleFormCancel() {
    showVolunteerForm = false;
    selectedVolunteer = null;
  }

  async function handleDeleteVolunteer(volunteer: Volunteer) {
    if (confirm(`Are you sure you want to remove ${getMemberName(volunteer.member_id)} from this role?`)) {
      try {
        await volunteers.deleteVolunteer(volunteer.id);
        await loadEventVolunteers();
      } catch (error) {
        // Error handling is done in the store
      }
    }
  }

  function getMemberName(memberId: number): string {
    const member = availableMembers.find(m => m.id === memberId);
    return member?.name || 'Unknown Member';
  }

  function getStatusBadgeClass(status: string): string {
    switch (status) {
      case 'active':
        return 'bg-green-100 text-green-800';
      case 'completed':
        return 'bg-blue-100 text-blue-800';
      case 'inactive':
        return 'bg-gray-100 text-gray-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  }

  function handleClose() {
    onClose?.();
  }
</script>

{#if isOpen}
  <Modal title="Volunteer Assignments" onClose={handleClose} size="lg">
    <div class="space-y-6">
      <!-- Event Info -->
      {#if selectedEvent}
        <div class="bg-blue-50 p-4 rounded-lg">
          <h3 class="font-medium text-blue-900">{selectedEvent.title}</h3>
          <p class="text-blue-700 text-sm">
            {new Date(selectedEvent.start_date).toLocaleDateString()}
          </p>
          {#if selectedEvent.location}
            <p class="text-blue-600 text-sm">{selectedEvent.location}</p>
          {/if}
        </div>
      {/if}

      <!-- Header with Create Button -->
      <div class="flex justify-between items-center">
        <h4 class="text-lg font-medium">Volunteer Assignments</h4>
        <Button onclick={handleCreateAssignment}>
          Add Volunteer
        </Button>
      </div>

      <!-- Volunteers List -->
      {#if loading}
        <div class="text-center py-8">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
          <p class="mt-2 text-gray-600">Loading volunteers...</p>
        </div>
      {:else if eventVolunteers.length === 0}
        <div class="text-center py-8">
          <p class="text-gray-500">No volunteers assigned yet</p>
          <Button onclick={handleCreateAssignment} class="mt-4">
            Add First Volunteer
          </Button>
        </div>
      {:else}
        <div class="grid gap-4">
          {#each eventVolunteers as volunteer (volunteer.id)}
            <div class="border rounded-lg p-4 hover:bg-gray-50">
              <div class="flex justify-between items-start">
                <div class="flex-1">
                  <div class="flex items-center gap-3 mb-2">
                    <h5 class="font-medium">{getMemberName(volunteer.member_id)}</h5>
                    <span class="px-2 py-1 rounded-full text-xs font-medium {getStatusBadgeClass(volunteer.status)}">
                      {volunteer.status}
                    </span>
                  </div>
                  
                  <div class="grid grid-cols-2 gap-4 text-sm text-gray-600">
                    <div>
                      <span class="font-medium">Role:</span> {volunteer.role}
                    </div>
                    <div>
                      <span class="font-medium">Hours:</span> {volunteer.hours}
                    </div>
                    <div>
                      <span class="font-medium">Start Date:</span> 
                      {new Date(volunteer.start_date).toLocaleDateString()}
                    </div>
                    {#if volunteer.end_date}
                      <div>
                        <span class="font-medium">End Date:</span> 
                        {new Date(volunteer.end_date).toLocaleDateString()}
                      </div>
                    {/if}
                  </div>
                  
                  {#if volunteer.notes}
                    <div class="mt-2 text-sm text-gray-600">
                      <span class="font-medium">Notes:</span> {volunteer.notes}
                    </div>
                  {/if}
                </div>
                
                <!-- Actions -->
                <div class="flex gap-2 ml-4">
                  <Button
                    variant="secondary"
                    size="sm"
                    onclick={() => handleEditVolunteer(volunteer)}
                  >
                    Edit
                  </Button>
                  <Button
                    variant="error"
                    size="sm"
                    onclick={() => handleDeleteVolunteer(volunteer)}
                  >
                    Remove
                  </Button>
                </div>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  </Modal>
{/if}

<!-- Volunteer Form Modal -->
{#if showVolunteerForm}
  <Modal
    title={selectedVolunteer ? 'Edit Volunteer Assignment' : 'Add Volunteer Assignment'}
    onClose={handleFormCancel}
    size="lg"
  >
    <VolunteerForm
      initialData={selectedVolunteer ? {
        member_id: selectedVolunteer.member_id,
        event_id: selectedVolunteer.event_id,
        role: selectedVolunteer.role,
        hours: selectedVolunteer.hours,
        notes: selectedVolunteer.notes,
        status: selectedVolunteer.status,
        start_date: selectedVolunteer.start_date,
        end_date: selectedVolunteer.end_date
      } : { event_id: eventId || selectedEvent?.id }}
      isEditing={!!selectedVolunteer}
      onSubmit={handleFormSubmit}
      onCancel={handleFormCancel}
    />
  </Modal>
{/if}
