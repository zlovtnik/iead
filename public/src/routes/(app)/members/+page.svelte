<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { members } from '$lib/stores/members.js';
  import { type Member } from '$lib/api/members.js';
  import authStore from '$lib/stores/auth.js';
  import { hasPermission } from '$lib/utils/permissions.js';
  import DataTable from '$lib/components/ui/DataTable.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Modal from '$lib/components/ui/Modal.svelte';
  import type { TableConfig } from '$lib/types/table.js';

  let searchQuery = $state('');
  let showDeleteModal = $state(false);
  let memberToDelete: Member | null = $state(null);
  let isDeleting = $state(false);

  // Subscribe to stores
  let membersData = $state<Member[]>([]);
  let isLoading = $state(false);
  let error = $state<string | null>(null);
  let pagination = $state({ page: 1, limit: 20, total: 0, totalPages: 0, pageSize: 20 });
  let user = $state<any>(null);

  // Subscribe to store updates
  members.subscribe((state) => {
    membersData = state.members;
    isLoading = state.isLoading;
    error = state.error;
    pagination = { ...state.pagination, pageSize: state.pagination.limit };
  });

  authStore.subscribe((state: any) => {
    user = state.user;
  });

  // Table configuration
  const tableConfig: TableConfig = {
    columns: [
      {
        key: 'name',
        label: 'Name',
        sortable: true,
        render: (value: string) => value || 'N/A'
      },
      {
        key: 'email',
        label: 'Email',
        sortable: true,
        render: (value: string) => value || 'N/A'
      },
      {
        key: 'phone',
        label: 'Phone',
        render: (value: string) => value || 'N/A'
      },
      {
        key: 'salary',
        label: 'Salary',
        align: 'right',
        render: (value: number) => value ? `$${value.toLocaleString()}` : 'N/A'
      },
      {
        key: 'created_at',
        label: 'Created',
        sortable: true,
        render: (value: string) => new Date(value).toLocaleDateString()
      }
    ],
    actions: [
      {
        label: 'View',
        variant: 'primary',
        onClick: (member: Member) => goto(`/members/${member.id}`),
        permission: 'member:read'
      },
      {
        label: 'Edit',
        onClick: (member: Member) => goto(`/members/${member.id}/edit`),
        permission: 'member:write',
        visible: (member: Member) => hasPermission(user, 'member:write')
      },
      {
        label: 'Delete',
        variant: 'danger',
        onClick: (member: Member) => {
          memberToDelete = member;
          showDeleteModal = true;
        },
        permission: 'member:delete',
        visible: (member: Member) => hasPermission(user, 'member:delete')
      }
    ],
    selectable: false,
    hover: true,
    striped: true
  };

  // Search functionality
  let searchTimeout: number;
  function handleSearch() {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      members.setSearchQuery(searchQuery);
    }, 300);
  }

  // Pagination handlers
  function handlePageChange(newPage: number) {
    members.setPage(newPage);
  }

  function handlePageSizeChange(newSize: number) {
    members.setPageSize(newSize);
  }

  // Sorting handler
  function handleSort(sort: { column: string; direction: 'asc' | 'desc' | null }) {
    if (sort.direction && (sort.column === 'name' || sort.column === 'email' || sort.column === 'created_at')) {
      members.setSorting(sort.column as any, sort.direction);
    }
  }

  // Delete member
  async function confirmDelete() {
    if (!memberToDelete) return;
    
    isDeleting = true;
    try {
      await members.deleteMember(memberToDelete.id);
      showDeleteModal = false;
      memberToDelete = null;
    } catch (err) {
      console.error('Failed to delete member:', err);
    } finally {
      isDeleting = false;
    }
  }

  function cancelDelete() {
    showDeleteModal = false;
    memberToDelete = null;
  }

  // Load members on mount
  onMount(() => {
    members.loadMembers();
  });

  // Check permissions
  const canCreateMember = $derived(hasPermission(user, 'member:write'));
  const canExportMembers = $derived(hasPermission(user, 'member:read'));
</script>

<svelte:head>
  <title>Members - Church Management</title>
</svelte:head>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex justify-between items-center">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Members</h1>
      <p class="text-gray-600">Manage church member information and records</p>
    </div>
    
    <div class="flex space-x-3">
      {#if canExportMembers}
        <Button
          variant="outline"
          onclick={() => members.exportMembers('csv')}
        >
          Export CSV
        </Button>
      {/if}
      
      {#if canCreateMember}
        <Button
          variant="primary"
          onclick={() => goto('/members/create')}
        >
          Add Member
        </Button>
      {/if}
    </div>
  </div>

  <!-- Search and Filters -->
  <div class="bg-white p-4 rounded-lg shadow">
    <div class="flex flex-col sm:flex-row gap-4">
      <div class="flex-1">
        <Input
          type="search"
          placeholder="Search members by name or email..."
          value={searchQuery}
          oninput={(e) => {
            searchQuery = (e.target as HTMLInputElement).value;
            handleSearch();
          }}
          fullWidth
        />
      </div>
      
      <div class="flex space-x-2">
        <Button
          variant="outline"
          onclick={() => {
            searchQuery = '';
            members.clearFilters();
          }}
        >
          Clear Filters
        </Button>
      </div>
    </div>
  </div>

  <!-- Error Display -->
  {#if error}
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
        <div class="ml-auto pl-3">
          <button
            type="button"
            class="inline-flex text-red-400 hover:text-red-600"
            onclick={() => members.clearError()}
          >
            <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  {/if}

  <!-- Members Table -->
  <div class="bg-white rounded-lg shadow">
    <DataTable
      data={membersData}
      config={tableConfig}
      loading={isLoading}
      error={error}
      pagination={pagination}
      user={user}
      emptyMessage="No members found. Add your first member to get started."
      onsort={(event) => handleSort(event)}
      onpaginate={(event) => {
        const { page, limit } = event;
        if (page !== undefined) handlePageChange(page);
        if (limit !== undefined) handlePageSizeChange(limit);
      }}
    />
  </div>
</div>

<!-- Delete Confirmation Modal -->
<Modal
  open={showDeleteModal}
  title="Delete Member"
  size="md"
  closable={!isDeleting}
>
  {#snippet children()}
    <div class="space-y-4">
      <div class="flex items-center space-x-3">
        <div class="flex-shrink-0">
          <svg class="h-8 w-8 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
          </svg>
        </div>
        <div>
          <h3 class="text-lg font-medium text-gray-900">
            Are you sure you want to delete this member?
          </h3>
          <p class="text-sm text-gray-500 mt-1">
            This action will permanently delete <strong>{memberToDelete?.name}</strong> and all associated records including donations, attendance, and volunteer history. This action cannot be undone.
          </p>
        </div>
      </div>
    </div>
  {/snippet}
  
  {#snippet footer()}
    <div class="flex justify-end space-x-3">
      <Button
        variant="outline"
        onclick={cancelDelete}
        disabled={isDeleting}
      >
        Cancel
      </Button>
      <Button
        variant="error"
        onclick={confirmDelete}
        loading={isDeleting}
        disabled={isDeleting}
      >
        Delete Member
      </Button>
    </div>
  {/snippet}
</Modal>