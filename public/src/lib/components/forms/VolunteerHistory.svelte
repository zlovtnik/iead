<script lang="ts">
  import type { VolunteerHistory, VolunteerHoursReport } from '$lib/api/volunteers.js';
  import { volunteerHours } from '$lib/stores/volunteers.js';
  import { onMount } from 'svelte';

  interface Props {
    memberId: number;
    memberName?: string;
  }

  let { memberId, memberName }: Props = $props();

  let loading = $state(false);
  let history = $state<VolunteerHistory[]>([]);
  let hoursReport = $state<VolunteerHoursReport | null>(null);

  onMount(() => {
    loadVolunteerData();
  });

  $effect(() => {
    if (memberId) {
      loadVolunteerData();
    }
  });

  async function loadVolunteerData() {
    loading = true;
    try {
      await Promise.all([
        volunteerHours.loadHoursReport(memberId),
        volunteerHours.loadHistory(memberId, { limit: 20 })
      ]);
      
      const state = $volunteerHours;
      hoursReport = state.hoursReport;
      history = state.history;
    } catch (error) {
      console.error('Failed to load volunteer data:', error);
    } finally {
      loading = false;
    }
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

  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString();
  }

  function calculateDuration(startDate: string, endDate?: string): string {
    const start = new Date(startDate);
    const end = endDate ? new Date(endDate) : new Date();
    const diffTime = Math.abs(end.getTime() - start.getTime());
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays < 7) {
      return `${diffDays} day${diffDays !== 1 ? 's' : ''}`;
    } else if (diffDays < 30) {
      const weeks = Math.floor(diffDays / 7);
      return `${weeks} week${weeks !== 1 ? 's' : ''}`;
    } else {
      const months = Math.floor(diffDays / 30);
      return `${months} month${months !== 1 ? 's' : ''}`;
    }
  }
</script>

<div class="space-y-6">
  <!-- Header -->
  <div class="border-b pb-4">
    <h3 class="text-lg font-semibold">
      Volunteer History - {memberName || 'Member'}
    </h3>
  </div>

  {#if loading}
    <!-- Loading State -->
    <div class="text-center py-8">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
      <p class="mt-2 text-gray-600">Loading volunteer history...</p>
    </div>
  {:else}
    <!-- Summary Report -->
    {#if hoursReport}
      <div class="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg p-6">
        <h4 class="text-lg font-medium text-gray-900 mb-4">Volunteer Summary</h4>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="text-center">
            <div class="text-3xl font-bold text-blue-600">{hoursReport.total_hours}</div>
            <div class="text-sm text-gray-600">Total Hours</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold text-green-600">{hoursReport.active_assignments}</div>
            <div class="text-sm text-gray-600">Active Assignments</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold text-purple-600">{hoursReport.completed_assignments}</div>
            <div class="text-sm text-gray-600">Completed Assignments</div>
          </div>
        </div>
      </div>
    {/if}

    <!-- History List -->
    <div>
      <h4 class="text-lg font-medium text-gray-900 mb-4">Recent Activity</h4>
      
      {#if history.length === 0}
        <div class="text-center py-8 text-gray-500">
          <svg class="w-12 h-12 mx-auto mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
          </svg>
          <p>No volunteer history found</p>
          <p class="text-sm">This member hasn't been assigned to any volunteer roles yet.</p>
        </div>
      {:else}
        <div class="space-y-4">
          {#each history as item (item.volunteer.id)}
            <div class="border rounded-lg p-4 hover:bg-gray-50 transition-colors">
              <div class="flex justify-between items-start">
                <div class="flex-1">
                  <div class="flex items-center gap-3 mb-2">
                    <h5 class="font-medium text-gray-900">{item.volunteer.role}</h5>
                    <span class="px-2 py-1 rounded-full text-xs font-medium {getStatusBadgeClass(item.volunteer.status)}">
                      {item.volunteer.status}
                    </span>
                  </div>
                  
                  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 text-sm text-gray-600">
                    {#if item.event_title}
                      <div>
                        <span class="font-medium">Event:</span> {item.event_title}
                      </div>
                    {/if}
                    <div>
                      <span class="font-medium">Hours:</span> {item.volunteer.hours}
                    </div>
                    <div>
                      <span class="font-medium">Started:</span> {formatDate(item.volunteer.start_date)}
                    </div>
                    <div>
                      <span class="font-medium">Duration:</span>
                      {calculateDuration(item.volunteer.start_date, item.volunteer.end_date)}
                    </div>
                  </div>
                  
                  {#if item.volunteer.notes}
                    <div class="mt-2 text-sm text-gray-600">
                      <span class="font-medium">Notes:</span> {item.volunteer.notes}
                    </div>
                  {/if}
                </div>
                
                <!-- Status Indicator -->
                <div class="ml-4">
                  {#if item.volunteer.status === 'active'}
                    <div class="w-3 h-3 bg-green-400 rounded-full animate-pulse"></div>
                  {:else if item.volunteer.status === 'completed'}
                    <div class="w-3 h-3 bg-blue-400 rounded-full"></div>
                  {:else}
                    <div class="w-3 h-3 bg-gray-400 rounded-full"></div>
                  {/if}
                </div>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  {/if}
</div>
