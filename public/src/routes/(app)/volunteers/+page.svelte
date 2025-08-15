<script lang="ts">
  import { onMount } from 'svelte';
  import { Button, DataTable, Loading, Toast } from '../../../lib/components/ui/index.js';
  import { VolunteerForm, VolunteerAssignment, VolunteerCompletion } from '../../../lib/components/forms/index.js';
  import { volunteers, isVolunteersLoading, hasVolunteerError } from '../../../lib/stores/volunteers.js';
  import { members } from '../../../lib/stores/members.js';
  import { events } from '../../../lib/stores/events.js';
  import type { Volunteer } from '../../../lib/api/volunteers.js';
  import type { TableColumn, TableAction } from '../../../lib/types/table.js';
  import { authState } from '../../../lib/stores/auth.js';

  let showVolunteerForm = $state(false);
  let showAssignmentForm = $state(false);
  let showCompletionForm = $state(false);
  let selectedVolunteer = $state<Volunteer | null>(null);
  let toast = $state({ show: false, message: '', type: 'success' as 'success' | 'error' });

  onMount(() => {
    loadInitialData();
  });

  async function loadInitialData() {
    try {
      await Promise.all([
        volunteers.loadVolunteers(),
        members.loadMembers(),
        events.loadEvents(),
        volunteers.loadVolunteerRoles()
      ]);
    } catch (error) {
      console.error('Failed to load initial data:', error);
      showToast('Failed to load volunteer data', 'error');
    }
  }

  function showToast(message: string, type: 'success' | 'error' = 'success') {
    toast = { show: true, message, type };
  }

  function handleCreateVolunteer() {
    selectedVolunteer = null;
    showVolunteerForm = true;
  }

  function handleEditVolunteer(volunteer: Volunteer) {
    selectedVolunteer = volunteer;
    showVolunteerForm = true;
  }

  function handleAssignVolunteer() {
    showAssignmentForm = true;
  }

  function handleCompleteAssignment(volunteer: Volunteer) {
    selectedVolunteer = volunteer;
    showCompletionForm = true;
  }

  async function handleDeleteVolunteer(volunteer: Volunteer) {
    if (!confirm(`Are you sure you want to delete the volunteer assignment for ${volunteer.member_name || 'this member'}?`)) {
      return;
    }

    try {
      await volunteers.deleteVolunteer(volunteer.id);
      showToast('Volunteer assignment deleted successfully');
    } catch (error) {
      console.error('Failed to delete volunteer:', error);
      showToast('Failed to delete volunteer assignment', 'error');
    }
  }

  function handleVolunteerFormSubmit(event: CustomEvent<Volunteer>) {
    showVolunteerForm = false;
    showToast(
      selectedVolunteer 
        ? 'Volunteer assignment updated successfully' 
        : 'Volunteer assignment created successfully'
    );
  }

  function handleAssignmentSubmit(event: CustomEvent<Volunteer>) {
    showAssignmentForm = false;
    showToast('Volunteer assigned to event successfully');
  }

  function handleCompletionSubmit(event: CustomEvent<Volunteer>) {
    showCompletionForm = false;
    showToast('Volunteer assignment completed successfully');
  }

  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString();
  }

  function getStatusColor(status: string): string {
    switch (status) {
      case 'active': return 'text-blue-600 bg-blue-100';
      case 'completed': return 'text-green-600 bg-green-100';
      case 'inactive': return 'text-gray-600 bg-gray-100';
      default: return 'text-gray-600 bg-gray-100';
    }
  }

  // Table configuration
  const columns: TableColumn<Volunteer>[] = [
    {
      key: 'member_name',
      label: 'Member',
      sortable: true,
      render: (volunteer) => volunteer.member_name || 'Unknown'
    },
    {
      key: 'role',
      label: 'Role',
      sortable: true
    },
    {
      key: 'event_title',
      label: 'Event',
      render: (volunteer) => volunteer.event_title || 'General Assignment'
    },
    {
      key: 'hours',
      label: 'Hours',
      sortable: true,
      render: (volunteer) => `${volunteer.hours} hrs`
    },
    {
      key: 'status',
      label: 'Status',
      sortable: true,
      render: (volunteer) => `
        <span class="status-badge ${getStatusColor(volunteer.status)}">
          ${volunteer.status.toUpperCase()}
        </span>
      `
    },
    {
      key: 'start_date',
      label: 'Start Date',
      sortable: true,
      render: (volunteer) => formatDate(volunteer.start_date)
    },
    {
      key: 'created_at',
      label: 'Created',
      sortable: true,
      render: (volunteer) => formatDate(volunteer.created_at)
    }
  ];

  const actions: TableAction<Volunteer>[] = [
    {
      label: 'Edit',
      variant: 'secondary',
      onclick: handleEditVolunteer,
      visible: () => $authState.hasRole(['Admin', 'Pastor'])
    },
    {
      label: 'Complete',
      variant: 'success',
      onclick: handleCompleteAssignment,
      visible: (volunteer) => volunteer.status === 'active' && $authState.hasRole(['Admin', 'Pastor'])
    },
    {
      label: 'Delete',
      variant: 'error',
      onclick: handleDeleteVolunteer,
      visible: () => $authState.hasRole(['Admin', 'Pastor'])
    }
  ];

  // Search and filter handlers
  async function handleSearch(query: string) {
    await volunteers.setSearchQuery(query);
  }

  async function handleFilterChange(filters: any) {
    await volunteers.setFilters(filters);
  }

  async function handleSort(sortBy: string, sortOrder: 'asc' | 'desc') {
    await volunteers.setSorting(sortBy as any, sortOrder);
  }

  async function handlePageChange(page: number) {
    await volunteers.setPage(page);
  }

  async function handlePageSizeChange(pageSize: number) {
    await volunteers.setPageSize(pageSize);
  }
</script>

<svelte:head>
  <title>Volunteer Management - Church Management</title>
</svelte:head>

<div class="volunteer-management">
  <div class="page-header">
    <div class="header-content">
      <h1 class="page-title">Volunteer Management</h1>
      <p class="page-description">
        Manage volunteer assignments, track hours, and coordinate events
      </p>
    </div>
    
    <div class="header-actions">
      <Button variant="secondary" onclick={handleAssignVolunteer}>
        Assign to Event
      </Button>
      <Button variant="primary" onclick={handleCreateVolunteer}>
        New Assignment
      </Button>
    </div>
  </div>

  {#if $hasVolunteerError}
    <div class="error-banner">
      <p>❌ {$volunteers.error}</p>
      <Button variant="secondary" size="sm" onclick={() => volunteers.clearError()}>
        Dismiss
      </Button>
    </div>
  {/if}

  <!-- Volunteer Table -->
  <div class="table-container">
    <DataTable
      data={$volunteers.volunteers}
      {columns}
      {actions}
      pagination={$volunteers.pagination}
      loading={$isVolunteersLoading}
      onSearch={handleSearch}
      onFilter={handleFilterChange}
      onSort={handleSort}
      onPageChange={handlePageChange}
      onPageSizeChange={handlePageSizeChange}
      searchPlaceholder="Search volunteers by name, role, or event..."
      emptyMessage="No volunteer assignments found"
    >
      <!-- Custom filters slot -->
      <div slot="filters" class="custom-filters">
        <select 
          onchange={(e) => {
            const target = e.target as HTMLSelectElement;
            handleFilterChange({ status: target.value || undefined });
          }}
          class="filter-select"
        >
          <option value="">All Statuses</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
          <option value="completed">Completed</option>
        </select>

        <select 
          onchange={(e) => {
            const target = e.target as HTMLSelectElement;
            handleFilterChange({ member_id: target.value ? Number(target.value) : undefined });
          }}
          class="filter-select"
        >
          <option value="">All Members</option>
          {#each $members.members as member}
            <option value={member.id}>{member.name}</option>
          {/each}
        </select>

        <select 
          onchange={(e) => {
            const target = e.target as HTMLSelectElement;
            handleFilterChange({ event_id: target.value ? Number(target.value) : undefined });
          }}
          class="filter-select"
        >
          <option value="">All Events</option>
          {#each $events.events as event}
            <option value={event.id}>{event.title}</option>
          {/each}
        </select>
      </div>
    </DataTable>
  </div>

  <!-- Forms -->
  <VolunteerForm
    bind:open={showVolunteerForm}
    volunteer={selectedVolunteer}
    onsubmit={handleVolunteerFormSubmit}
    onclose={() => showVolunteerForm = false}
  />

  <VolunteerAssignment
    bind:open={showAssignmentForm}
    onassign={handleAssignmentSubmit}
    onclose={() => showAssignmentForm = false}
  />

  <VolunteerCompletion
    bind:open={showCompletionForm}
    volunteer={selectedVolunteer}
    oncomplete={handleCompletionSubmit}
    onclose={() => showCompletionForm = false}
  />

  <!-- Toast -->
  {#if toast.show}
    <Toast
      message={toast.message}
      type={toast.type}
      onclose={() => toast.show = false}
    />
  {/if}
</div>

<style>
  .volunteer-management {
    padding: 1.5rem;
    max-width: 1200px;
    margin: 0 auto;
  }

  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 2rem;
    gap: 1rem;
  }

  .header-content {
    flex: 1;
  }

  .page-title {
    font-size: 2rem;
    font-weight: 700;
    color: #111827;
    margin: 0 0 0.5rem 0;
  }

  .page-description {
    color: #6b7280;
    margin: 0;
  }

  .header-actions {
    display: flex;
    gap: 1rem;
    flex-shrink: 0;
  }

  .error-banner {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    margin-bottom: 1rem;
    background-color: #fef2f2;
    border: 1px solid #fecaca;
    border-radius: 0.5rem;
    color: #dc2626;
  }

  .table-container {
    background-color: white;
    border-radius: 0.5rem;
    border: 1px solid #e5e7eb;
    overflow: hidden;
  }

  .custom-filters {
    display: flex;
    gap: 1rem;
    align-items: center;
  }

  .filter-select {
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    background-color: white;
    font-size: 0.875rem;
    min-width: 150px;
  }

  .filter-select:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  /* Status badge styles for table content */
  :global(.status-badge) {
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 500;
    text-transform: uppercase;
  }

  :global(.text-blue-600) { color: #2563eb; }
  :global(.bg-blue-100) { background-color: #dbeafe; }
  :global(.text-green-600) { color: #16a34a; }
  :global(.bg-green-100) { background-color: #dcfce7; }
  :global(.text-gray-600) { color: #6b7280; }
  :global(.bg-gray-100) { background-color: #f3f4f6; }

  @media (max-width: 768px) {
    .volunteer-management {
      padding: 1rem;
    }

    .page-header {
      flex-direction: column;
      align-items: stretch;
    }

    .header-actions {
      justify-content: stretch;
    }

    .custom-filters {
      flex-direction: column;
      align-items: stretch;
    }

    .filter-select {
      min-width: auto;
    }
  }
</style>
