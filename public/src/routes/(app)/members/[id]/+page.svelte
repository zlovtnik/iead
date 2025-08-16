<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { members, type Member } from '$lib/stores/members.js';
  import { user } from '$lib/stores/auth.js';
  import { hasPermission } from '$lib/utils/permissions.js';
  import Button from '$lib/components/ui/Button.svelte';
  import Modal from '$lib/components/ui/Modal.svelte';
  import Loading from '$lib/components/ui/Loading.svelte';

  let memberId = $derived(parseInt($page.params.id));
  let member: Member | null = $state(null);
  let memberStats = $state<any>(null);
  let isLoading = $state(true);
  let isLoadingStats = $state(false);
  let error = $state<string | null>(null);
  let showDeleteModal = $state(false);
  let isDeleting = $state(false);

  // Subscribe to members store
  members.subscribe((state) => {
    if (state.selectedMember && state.selectedMember.id === memberId) {
      member = state.selectedMember;
    }
    error = state.error;
    isLoading = state.isLoading;
    isDeleting = state.isDeleting;
  });

  async function loadMember() {
    try {
      isLoading = true;
      member = await members.loadMember(memberId);
      
      // Load member statistics
      if (hasPermission(user, 'member:read')) {
        isLoadingStats = true;
        try {
          memberStats = await members.getMemberStats(memberId);
        } catch (err) {
          console.error('Failed to load member stats:', err);
        } finally {
          isLoadingStats = false;
        }
      }
    } catch (err) {
      console.error('Failed to load member:', err);
      error = 'Failed to load member details';
    } finally {
      isLoading = false;
    }
  }

  async function handleDelete() {
    if (!member) return;
    
    try {
      await members.deleteMember(member.id);
      await goto('/members');
    } catch (err) {
      console.error('Failed to delete member:', err);
    }
  }

  function confirmDelete() {
    showDeleteModal = true;
  }

  function cancelDelete() {
    showDeleteModal = false;
  }

  onMount(() => {
    loadMember();
  });

  // Check permissions
  const canEdit = $derived(hasPermission(user, 'member:write'));
  const canDelete = $derived(hasPermission(user, 'member:delete'));
  const canViewStats = $derived(hasPermission(user, 'member:read'));
</script>

<svelte:head>
  <title>{member?.name || 'Member'} - Church Management</title>
</svelte:head>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex justify-between items-start">
    <div>
      <div class="flex items-center space-x-2 text-sm text-gray-500 mb-2">
        <button
          onclick={() => goto('/members')}
          class="hover:text-gray-700 transition-colors"
        >
          Members
        </button>
        <span>›</span>
        <span>{member?.name || 'Loading...'}</span>
      </div>
      
      {#if member}
        <h1 class="text-2xl font-bold text-gray-900">{member.name}</h1>
        <p class="text-gray-600">Member since {new Date(member.created_at).toLocaleDateString()}</p>
      {:else}
        <h1 class="text-2xl font-bold text-gray-900">Loading...</h1>
      {/if}
    </div>
    
    <div class="flex space-x-3">
      {#if canEdit && member}
        <Button
          variant="outline"
          onclick={() => goto(`/members/${member.id}/edit`)}
        >
          Edit Member
        </Button>
      {/if}
      
      {#if canDelete && member}
        <Button
          variant="error"
          onclick={confirmDelete}
        >
          Delete Member
        </Button>
      {/if}
    </div>
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
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Member Information -->
      <div class="lg:col-span-2 space-y-6">
        <!-- Basic Information -->
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-4">Basic Information</h2>
          <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <dt class="text-sm font-medium text-gray-500">Full Name</dt>
              <dd class="mt-1 text-sm text-gray-900">{member.name}</dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Email</dt>
              <dd class="mt-1 text-sm text-gray-900">
                {#if member.email}
                  <a href="mailto:{member.email}" class="text-blue-600 hover:text-blue-800">
                    {member.email}
                  </a>
                {:else}
                  <span class="text-gray-400">Not provided</span>
                {/if}
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Phone</dt>
              <dd class="mt-1 text-sm text-gray-900">
                {#if member.phone}
                  <a href="tel:{member.phone}" class="text-blue-600 hover:text-blue-800">
                    {member.phone}
                  </a>
                {:else}
                  <span class="text-gray-400">Not provided</span>
                {/if}
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Member Since</dt>
              <dd class="mt-1 text-sm text-gray-900">
                {new Date(member.created_at).toLocaleDateString()}
              </dd>
            </div>
          </dl>
        </div>

        <!-- Financial Information -->
        {#if canViewStats}
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold text-gray-900 mb-4">Financial Information</h2>
            <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <dt class="text-sm font-medium text-gray-500">Annual Salary</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  {#if member.salary}
                    ${member.salary.toLocaleString()}
                  {:else}
                    <span class="text-gray-400">Not provided</span>
                  {/if}
                </dd>
              </div>
              
              {#if memberStats}
                <div>
                  <dt class="text-sm font-medium text-gray-500">Total Donations</dt>
                  <dd class="mt-1 text-sm text-gray-900">
                    ${memberStats.totalDonations?.toLocaleString() || '0'}
                  </dd>
                </div>
                
                <div>
                  <dt class="text-sm font-medium text-gray-500">Last Donation</dt>
                  <dd class="mt-1 text-sm text-gray-900">
                    {#if memberStats.lastDonation}
                      {new Date(memberStats.lastDonation).toLocaleDateString()}
                    {:else}
                      <span class="text-gray-400">No donations yet</span>
                    {/if}
                  </dd>
                </div>
              {:else if isLoadingStats}
                <div class="col-span-2">
                  <div class="animate-pulse">
                    <div class="h-4 bg-gray-200 rounded w-3/4"></div>
                  </div>
                </div>
              {/if}
            </dl>
          </div>
        {/if}
      </div>

      <!-- Statistics Sidebar -->
      {#if canViewStats}
        <div class="space-y-6">
          <!-- Engagement Stats -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Engagement</h3>
            
            {#if memberStats}
              <div class="space-y-4">
                <div>
                  <div class="flex justify-between items-center">
                    <span class="text-sm font-medium text-gray-500">Attendance Rate</span>
                    <span class="text-sm text-gray-900">
                      {memberStats.attendanceRate ? `${memberStats.attendanceRate}%` : 'N/A'}
                    </span>
                  </div>
                  {#if memberStats.attendanceRate}
                    <div class="mt-1 w-full bg-gray-200 rounded-full h-2">
                      <div 
                        class="bg-blue-600 h-2 rounded-full" 
                        style="width: {memberStats.attendanceRate}%"
                      ></div>
                    </div>
                  {/if}
                </div>
                
                <div>
                  <div class="flex justify-between items-center">
                    <span class="text-sm font-medium text-gray-500">Volunteer Hours</span>
                    <span class="text-sm text-gray-900">
                      {memberStats.volunteerHours || 0}
                    </span>
                  </div>
                </div>
                
                <div>
                  <div class="flex justify-between items-center">
                    <span class="text-sm font-medium text-gray-500">Last Attendance</span>
                    <span class="text-sm text-gray-900">
                      {#if memberStats.lastAttendance}
                        {new Date(memberStats.lastAttendance).toLocaleDateString()}
                      {:else}
                        <span class="text-gray-400">Never</span>
                      {/if}
                    </span>
                  </div>
                </div>
              </div>
            {:else if isLoadingStats}
              <div class="space-y-4">
                <div class="animate-pulse">
                  <div class="h-4 bg-gray-200 rounded w-full"></div>
                  <div class="h-2 bg-gray-200 rounded w-full mt-2"></div>
                </div>
                <div class="animate-pulse">
                  <div class="h-4 bg-gray-200 rounded w-3/4"></div>
                </div>
                <div class="animate-pulse">
                  <div class="h-4 bg-gray-200 rounded w-2/3"></div>
                </div>
              </div>
            {:else}
              <p class="text-sm text-gray-500">Unable to load statistics</p>
            {/if}
          </div>

          <!-- Quick Actions -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
            <div class="space-y-2">
              <Button
                variant="outline"
                fullWidth
                onclick={() => goto(`/donations?member=${member.id}`)}
              >
                View Donations
              </Button>
              <Button
                variant="outline"
                fullWidth
                onclick={() => goto(`/attendance?member=${member.id}`)}
              >
                View Attendance
              </Button>
              <Button
                variant="outline"
                fullWidth
                onclick={() => goto(`/volunteers?member=${member.id}`)}
              >
                View Volunteer History
              </Button>
            </div>
          </div>
        </div>
      {/if}
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
            This action will permanently delete <strong>{member?.name}</strong> and all associated records including donations, attendance, and volunteer history. This action cannot be undone.
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
        onclick={handleDelete}
        loading={isDeleting}
        disabled={isDeleting}
      >
        Delete Member
      </Button>
    </div>
  {/snippet}
</Modal>