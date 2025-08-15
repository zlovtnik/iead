<script lang="ts">
  import { onMount } from 'svelte';
  import { Button, Loading } from '../ui/index.js';
  import { volunteers } from '../../stores/volunteers.js';
  import type { VolunteerHistory, VolunteerHoursReport } from '../../api/volunteers.js';

  interface Props {
    memberId: number;
    memberName?: string;
    showFullHistory?: boolean;
  }

  let {
    memberId,
    memberName = 'Member',
    showFullHistory = false
  }: Props = $props();

  let isLoading = $state(false);
  let hoursReport = $state<VolunteerHoursReport | null>(null);
  let history = $state<VolunteerHistory[]>([]);
  let error = $state<string | null>(null);
  let historyFilter = $state<'all' | 'active' | 'completed'>('all');

  onMount(() => {
    loadVolunteerData();
  });

  async function loadVolunteerData() {
    isLoading = true;
    error = null;

    try {
      // Load hours report and history in parallel
      const [hoursData, historyData] = await Promise.all([
        volunteers.loadVolunteerHours(memberId),
        volunteers.loadVolunteerHistory(memberId, {
          limit: showFullHistory ? undefined : 10,
          status: historyFilter === 'all' ? undefined : historyFilter as any
        })
      ]);

      hoursReport = hoursData;
      history = historyData;
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load volunteer data';
      console.error('Failed to load volunteer data:', err);
    } finally {
      isLoading = false;
    }
  }

  $effect(() => {
    // Reload data when filter changes
    if (historyFilter) {
      loadVolunteerData();
    }
  });

  function formatDuration(startDate: string, endDate?: string): string {
    const start = new Date(startDate);
    const end = endDate ? new Date(endDate) : new Date();
    const diffTime = Math.abs(end.getTime() - start.getTime());
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays === 1) return '1 day';
    if (diffDays < 30) return `${diffDays} days`;
    if (diffDays < 365) return `${Math.round(diffDays / 30)} months`;
    return `${Math.round(diffDays / 365)} years`;
  }

  function getStatusColor(status: string): string {
    switch (status) {
      case 'active': return 'text-blue-600 bg-blue-100';
      case 'completed': return 'text-green-600 bg-green-100';
      case 'inactive': return 'text-gray-600 bg-gray-100';
      default: return 'text-gray-600 bg-gray-100';
    }
  }

  const totalHours = $derived(hoursReport?.total_hours || 0);
  const activeAssignments = $derived(hoursReport?.active_assignments || 0);
  const completedAssignments = $derived(hoursReport?.completed_assignments || 0);
  const totalAssignments = $derived(activeAssignments + completedAssignments);

  const averageHoursPerAssignment = $derived(
    totalAssignments > 0 ? (totalHours / totalAssignments).toFixed(1) : '0'
  );

  const filteredHistory = $derived(
    historyFilter === 'all' 
      ? history 
      : history.filter(h => h.volunteer.status === historyFilter)
  );
</script>

<div class="volunteer-history">
  <div class="header">
    <h2 class="title">Volunteer History - {memberName}</h2>
    <Button variant="secondary" size="sm" onclick={loadVolunteerData} disabled={isLoading}>
      {#if isLoading}
        <Loading size="sm" />
      {:else}
        Refresh
      {/if}
    </Button>
  </div>

  {#if error}
    <div class="error-message">
      <p>❌ {error}</p>
      <Button variant="secondary" size="sm" onclick={loadVolunteerData}>
        Try Again
      </Button>
    </div>
  {:else if isLoading && !hoursReport}
    <div class="loading-state">
      <Loading />
      <p>Loading volunteer data...</p>
    </div>
  {:else}
    <!-- Hours Summary -->
    {#if hoursReport}
      <div class="hours-summary">
        <h3 class="summary-title">Volunteer Summary</h3>
        <div class="summary-grid">
          <div class="summary-card">
            <div class="card-value">{totalHours}</div>
            <div class="card-label">Total Hours</div>
          </div>
          <div class="summary-card">
            <div class="card-value">{activeAssignments}</div>
            <div class="card-label">Active Assignments</div>
          </div>
          <div class="summary-card">
            <div class="card-value">{completedAssignments}</div>
            <div class="card-label">Completed</div>
          </div>
          <div class="summary-card">
            <div class="card-value">{averageHoursPerAssignment}</div>
            <div class="card-label">Avg Hours/Assignment</div>
          </div>
        </div>
      </div>
    {/if}

    <!-- History Filters -->
    <div class="history-section">
      <div class="section-header">
        <h3 class="section-title">Assignment History</h3>
        <div class="filter-buttons">
          <button
            class="filter-btn"
            class:active={historyFilter === 'all'}
            onclick={() => historyFilter = 'all'}
          >
            All
          </button>
          <button
            class="filter-btn"
            class:active={historyFilter === 'active'}
            onclick={() => historyFilter = 'active'}
          >
            Active
          </button>
          <button
            class="filter-btn"
            class:active={historyFilter === 'completed'}
            onclick={() => historyFilter = 'completed'}
          >
            Completed
          </button>
        </div>
      </div>

      <!-- History List -->
      {#if filteredHistory.length > 0}
        <div class="history-list">
          {#each filteredHistory as item}
            <div class="history-item">
              <div class="item-header">
                <div class="role-info">
                  <span class="role">{item.volunteer.role}</span>
                  {#if item.event_title}
                    <span class="event">• {item.event_title}</span>
                  {/if}
                </div>
                <span class="status-badge {getStatusColor(item.volunteer.status)}">
                  {item.volunteer.status}
                </span>
              </div>
              
              <div class="item-details">
                <div class="detail-row">
                  <span class="label">Start Date:</span>
                  <span class="value">{new Date(item.volunteer.start_date).toLocaleDateString()}</span>
                </div>
                
                {#if item.volunteer.end_date}
                  <div class="detail-row">
                    <span class="label">End Date:</span>
                    <span class="value">{new Date(item.volunteer.end_date).toLocaleDateString()}</span>
                  </div>
                {/if}
                
                <div class="detail-row">
                  <span class="label">Duration:</span>
                  <span class="value">{formatDuration(item.volunteer.start_date, item.volunteer.end_date)}</span>
                </div>
                
                <div class="detail-row">
                  <span class="label">Hours:</span>
                  <span class="value">{item.volunteer.hours} hours</span>
                </div>
                
                {#if item.volunteer.notes}
                  <div class="notes">
                    <span class="label">Notes:</span>
                    <p class="notes-text">{item.volunteer.notes}</p>
                  </div>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      {:else}
        <div class="empty-state">
          <p>No volunteer assignments found for the selected filter.</p>
          {#if historyFilter !== 'all'}
            <Button variant="secondary" size="sm" onclick={() => historyFilter = 'all'}>
              Show All Assignments
            </Button>
          {/if}
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .volunteer-history {
    padding: 1rem;
  }

  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
  }

  .title {
    font-size: 1.5rem;
    font-weight: 700;
    color: #111827;
    margin: 0;
  }

  .error-message {
    text-align: center;
    padding: 2rem;
    color: #dc2626;
  }

  .loading-state {
    text-align: center;
    padding: 2rem;
    color: #6b7280;
  }

  .hours-summary {
    margin-bottom: 2rem;
    padding: 1.5rem;
    background-color: #f8fafc;
    border-radius: 0.5rem;
    border: 1px solid #e2e8f0;
  }

  .summary-title {
    font-size: 1.125rem;
    font-weight: 600;
    margin-bottom: 1rem;
    color: #374151;
  }

  .summary-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 1rem;
  }

  .summary-card {
    text-align: center;
    padding: 1rem;
    background-color: white;
    border-radius: 0.375rem;
    border: 1px solid #e5e7eb;
  }

  .card-value {
    font-size: 2rem;
    font-weight: 700;
    color: #1f2937;
  }

  .card-label {
    font-size: 0.875rem;
    color: #6b7280;
    margin-top: 0.25rem;
  }

  .history-section {
    background-color: white;
    border-radius: 0.5rem;
    border: 1px solid #e5e7eb;
    overflow: hidden;
  }

  .section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    background-color: #f9fafb;
    border-bottom: 1px solid #e5e7eb;
  }

  .section-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: #374151;
    margin: 0;
  }

  .filter-buttons {
    display: flex;
    gap: 0.5rem;
  }

  .filter-btn {
    padding: 0.5rem 1rem;
    border: 1px solid #d1d5db;
    background-color: white;
    color: #6b7280;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all 0.2s;
  }

  .filter-btn:hover {
    background-color: #f9fafb;
  }

  .filter-btn.active {
    background-color: #3b82f6;
    color: white;
    border-color: #3b82f6;
  }

  .history-list {
    /* Using border-bottom on items instead of divide-y */
  }

  .history-item {
    padding: 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }

  .history-item:last-child {
    border-bottom: none;
  }

  .item-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .role-info {
    flex: 1;
  }

  .role {
    font-weight: 600;
    color: #111827;
  }

  .event {
    color: #6b7280;
    margin-left: 0.5rem;
  }

  .status-badge {
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 500;
    text-transform: uppercase;
  }

  .item-details {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 0.75rem;
  }

  .detail-row {
    display: flex;
    justify-content: space-between;
  }

  .label {
    font-weight: 500;
    color: #6b7280;
  }

  .value {
    color: #111827;
  }

  .notes {
    grid-column: 1 / -1;
    margin-top: 0.5rem;
  }

  .notes-text {
    margin-top: 0.25rem;
    color: #4b5563;
    font-style: italic;
  }

  .empty-state {
    text-align: center;
    padding: 2rem;
    color: #6b7280;
  }

  /* Status colors */
  .text-blue-600 { color: #2563eb; }
  .bg-blue-100 { background-color: #dbeafe; }
  .text-green-600 { color: #16a34a; }
  .bg-green-100 { background-color: #dcfce7; }
  .text-gray-600 { color: #6b7280; }
  .bg-gray-100 { background-color: #f3f4f6; }
</style>
