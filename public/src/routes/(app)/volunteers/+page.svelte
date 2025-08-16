<script lang="ts">
  import { onMount } from 'svelte';
  import { volunteers, volunteerStats, hasActiveFilters } from '$lib/stores/volunteers.js';
  import { members } from '$lib/stores/members.js';
  import DataTable from '$lib/components/ui/DataTable.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Modal from '$lib/components/ui/Modal.svelte';
  import VolunteerForm from '$lib/components/forms/VolunteerForm.svelte';
  import VolunteerCompletion from '$lib/components/forms/VolunteerCompletion.svelte';
  import VolunteerHistory from '$lib/components/forms/VolunteerHistory.svelte';
  import type { Volunteer, VolunteerFormData } from '$lib/api/volunteers.js';

  let showCreateForm = $state(false);
  let showEditForm = $state(false);
  let showCompletionForm = $state(false);
  let showHistoryModal = $state(false);
  let selectedVolunteer = $state<Volunteer | null>(null);
  let selectedMemberId = $state<number>(0);
  let selectedMemberName = $state<string>('');

  // Search and filter state
  let searchQuery = $state('');
  let statusFilter = $state('');
  let roleFilter = $state('');

  onMount(() => {
    volunteers.loadVolunteers();
    members.loadMembers();
  });

  // Update search when input changes
  $effect(() => {
    const timeoutId = setTimeout(() => {
      volunteers.setSearchQuery(searchQuery);
      volunteers.loadVolunteers();
    }, 300);

    return () => clearTimeout(timeoutId);
  });

  // Update filters when they change
  $effect(() => {
    volunteers.setFilters({
      status: statusFilter || undefined,
      role: roleFilter || undefined
    });
    volunteers.loadVolunteers();
  });

  const columns = [
    {
      key: 'member_name',
      title: 'Member',
      sortable: true,
      render: (value: string, row: Volunteer) => {
        const member = $members.members.find(m => m.id === row.member_id);
        return member?.name || 'Unknown Member';
      }
    },
    {
      key: 'role',
      title: 'Role',
      sortable: true
    },
    {
      key: 'event_title',
      title: 'Event',
      render: (value: string) => value || 'General Assignment'
    },
    {
      key: 'hours',
      title: 'Hours',
      sortable: true,
      render: (value: number) => value.toString()
    },
    {
      key: 'status',
      title: 'Status',
      sortable: true,
      render: (value: string) => {
        const statusColors = {
          active: 'bg-green-100 text-green-800',
          completed: 'bg-blue-100 text-blue-800',
          inactive: 'bg-gray-100 text-gray-800'
        };
        const colorClass = statusColors[value as keyof typeof statusColors] || 'bg-gray-100 text-gray-800';
        return `<span class="px-2 py-1 rounded-full text-xs font-medium ${colorClass}">${value}</span>`;
      }
    },
    {
      key: 'start_date',
      title: 'Start Date',
      sortable: true,
      render: (value: string) => new Date(value).toLocaleDateString()
    },
    {
      key: 'actions',
      title: 'Actions',
      render: (_: any, row: Volunteer) => {
        return `
          <div class="flex gap-2">
            <button class="text-blue-600 hover:text-blue-800 text-sm" onclick="editVolunteer(${row.id})">
              Edit
            </button>
            <button class="text-green-600 hover:text-green-800 text-sm" onclick="completeVolunteer(${row.id})">
              Complete
            </button>
            <button class="text-purple-600 hover:text-purple-800 text-sm" onclick="viewHistory(${row.member_id})">
              History
            </button>
            <button class="text-red-600 hover:text-red-800 text-sm" onclick="deleteVolunteer(${row.id})">
              Delete
            </button>
          </div>
        `;
      }
    }
  ];

  // Make functions globally available for the table action buttons
  globalThis.editVolunteer = (id: number) => {
    selectedVolunteer = $volunteers.volunteers.find(v => v.id === id) || null;
    showEditForm = true;
  };

  globalThis.completeVolunteer = (id: number) => {
    selectedVolunteer = $volunteers.volunteers.find(v => v.id === id) || null;
    showCompletionForm = true;
  };

  globalThis.viewHistory = (memberId: number) => {
    const member = $members.members.find(m => m.id === memberId);
    selectedMemberId = memberId;
    selectedMemberName = member?.name || 'Unknown Member';
    showHistoryModal = true;
  };

  globalThis.deleteVolunteer = async (id: number) => {
    const volunteer = $volunteers.volunteers.find(v => v.id === id);
    if (!volunteer) return;

    const member = $members.members.find(m => m.id === volunteer.member_id);
    const memberName = member?.name || 'this volunteer';

    if (confirm(`Are you sure you want to delete the volunteer assignment for ${memberName}?`)) {
      await volunteers.deleteVolunteer(id);
    }
  };

  function handleCreateVolunteer() {
    selectedVolunteer = null;
    showCreateForm = true;
  }

  async function handleFormSubmit(data: VolunteerFormData) {
    try {
      if (selectedVolunteer) {
        await volunteers.updateVolunteer(selectedVolunteer.id, data);
        showEditForm = false;
      } else {
        await volunteers.createVolunteer(data);
        showCreateForm = false;
      }
      selectedVolunteer = null;
    } catch (error) {
      // Error handling is done in the store
    }
  }

  function handleFormCancel() {
    showCreateForm = false;
    showEditForm = false;
    selectedVolunteer = null;
  }

  async function handleCompletionSubmit(data: { actualHours: number; notes?: string }) {
    if (!selectedVolunteer) return;
    
    try {
      await volunteers.completeAssignment(selectedVolunteer.id, data.actualHours, data.notes);
      showCompletionForm = false;
      selectedVolunteer = null;
    } catch (error) {
      // Error handling is done in the store
    }
  }

  function handleCompletionCancel() {
    showCompletionForm = false;
    selectedVolunteer = null;
  }

  function clearFilters() {
    searchQuery = '';
    statusFilter = '';
    roleFilter = '';
    volunteers.clearFilters();
    volunteers.loadVolunteers();
  }

  function handleSort(column: string, direction: 'asc' | 'desc') {
    volunteers.setSorting(column, direction);
    volunteers.loadVolunteers();
  }

  function handlePageChange(page: number) {
    volunteers.setPage(page);
    volunteers.loadVolunteers();
  }
</script>

<svelte:head>
  <title>Volunteers - Church Management</title>
</svelte:head>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex justify-between items-center">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Volunteers</h1>
      <p class="text-gray-600">Manage volunteer assignments and track service hours</p>
    </div>
    <Button onclick={handleCreateVolunteer}>
      Add Volunteer
    </Button>
  </div>

  <!-- Stats Cards -->
  <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
    <div class="bg-white p-6 rounded-lg shadow-sm border">
      <div class="text-2xl font-bold text-blue-600">{$volunteerStats.totalVolunteers}</div>
      <div class="text-sm text-gray-600">Total Volunteers</div>
    </div>
    <div class="bg-white p-6 rounded-lg shadow-sm border">
      <div class="text-2xl font-bold text-green-600">{$volunteerStats.activeVolunteers}</div>
      <div class="text-sm text-gray-600">Active Assignments</div>
    </div>
    <div class="bg-white p-6 rounded-lg shadow-sm border">
      <div class="text-2xl font-bold text-purple-600">{$volunteerStats.completedVolunteers}</div>
      <div class="text-sm text-gray-600">Completed</div>
    </div>
    <div class="bg-white p-6 rounded-lg shadow-sm border">
      <div class="text-2xl font-bold text-orange-600">{$volunteerStats.totalHours}</div>
      <div class="text-sm text-gray-600">Total Hours</div>
    </div>
  </div>

  <!-- Search and Filters -->
  <div class="bg-white p-6 rounded-lg shadow-sm border">
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Search</label>
        <Input
          type="text"
          placeholder="Search volunteers..."
          bind:value={searchQuery}
        />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Status</label>
        <select
          bind:value={statusFilter}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">All Statuses</option>
          <option value="active">Active</option>
          <option value="completed">Completed</option>
          <option value="inactive">Inactive</option>
        </select>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Role</label>
        <Input
          type="text"
          placeholder="Filter by role..."
          bind:value={roleFilter}
        />
      </div>
      <div class="flex items-end">
        {#if $hasActiveFilters}
          <Button variant="secondary" onclick={clearFilters}>
            Clear Filters
          </Button>
        {/if}
      </div>
    </div>
  </div>

  <!-- Volunteers Table -->
  <div class="bg-white rounded-lg shadow-sm border">
    <DataTable
      data={$volunteers.volunteers}
      {columns}
      loading={$volunteers.loading}
      error={$volunteers.error}
      pagination={{
        page: $volunteers.currentPage,
        limit: $volunteers.pageSize,
        total: $volunteers.totalCount,
        totalPages: Math.ceil($volunteers.totalCount / $volunteers.pageSize)
      }}
      onSort={handleSort}
      onPageChange={handlePageChange}
      emptyMessage="No volunteers found"
    />
  </div>
</div>

<!-- Create Volunteer Modal -->
{#if showCreateForm}
  <Modal title="Add Volunteer Assignment" onClose={handleFormCancel} size="lg">
    <VolunteerForm
      onSubmit={handleFormSubmit}
      onCancel={handleFormCancel}
    />
  </Modal>
{/if}

<!-- Edit Volunteer Modal -->
{#if showEditForm && selectedVolunteer}
  <Modal title="Edit Volunteer Assignment" onClose={handleFormCancel} size="lg">
    <VolunteerForm
      initialData={{
        member_id: selectedVolunteer.member_id,
        event_id: selectedVolunteer.event_id,
        role: selectedVolunteer.role,
        hours: selectedVolunteer.hours,
        notes: selectedVolunteer.notes,
        status: selectedVolunteer.status,
        start_date: selectedVolunteer.start_date,
        end_date: selectedVolunteer.end_date
      }}
      isEditing={true}
      onSubmit={handleFormSubmit}
      onCancel={handleFormCancel}
    />
  </Modal>
{/if}

<!-- Complete Assignment Modal -->
{#if showCompletionForm && selectedVolunteer}
  <Modal title="Complete Volunteer Assignment" onClose={handleCompletionCancel} size="lg">
    <VolunteerCompletion
      volunteer={selectedVolunteer}
      onSubmit={handleCompletionSubmit}
      onCancel={handleCompletionCancel}
    />
  </Modal>
{/if}

<!-- Volunteer History Modal -->
{#if showHistoryModal}
  <Modal title="Volunteer History" onClose={() => showHistoryModal = false} size="xl">
    <VolunteerHistory
      memberId={selectedMemberId}
      memberName={selectedMemberName}
    />
  </Modal>
{/if}
