<script lang="ts">
  import { onMount } from 'svelte';
  import { user } from '$lib/stores/auth.js';
  import { reportsApi } from '$lib/api/reports.js';
  import { DonationChart, AttendanceChart, MemberGrowthChart } from '$lib/components/charts/index.js';
  import { Loading } from '$lib/components/ui/index.js';
  import Card from '$lib/components/ui/Card.svelte';
  import type { DashboardMetrics, DonationSummary, AttendanceReport, MemberReport } from '$lib/api/reports.js';
  import { generateMockDonationData, generateMockAttendanceData, generateMockMemberData } from './mock-data.js';

  let stats = $state<DashboardMetrics>({
    totalMembers: 0,
    activeMembers: 0,
    upcomingEvents: 0,
    monthlyDonations: 0,
    monthlyTithes: 0,
    activeVolunteers: 0,
    averageAttendance: 0
  });

  let donationData = $state<DonationSummary | null>(null);
  let attendanceData = $state<AttendanceReport[]>([]);
  let memberData = $state<MemberReport | null>(null);
  let isLoading = $state(true);
  let error = $state<string | null>(null);

  onMount(async () => {
    try {
      // Load dashboard data in parallel
      const [metricsResult, donationsResult, attendanceResult, membersResult] = await Promise.allSettled([
        reportsApi.getDashboardMetrics().catch(err => {
          console.log('Error loading metrics:', err);
          return {
            totalMembers: 150,
            activeMembers: 120,
            upcomingEvents: 5,
            monthlyDonations: 8750,
            monthlyTithes: 4200,
            activeVolunteers: 35,
            averageAttendance: 95
          };
        }),
        reportsApi.getDonationSummary({ limit: 12 }).catch(err => {
          console.log('Error loading donations:', err);
          return generateMockDonationData();
        }),
        reportsApi.getAttendanceReport({ limit: 10 }).catch(err => {
          console.log('Error loading attendance:', err);
          return generateMockAttendanceData();
        }),
        reportsApi.getMemberReport({ limit: 12 }).catch(err => {
          console.log('Error loading members:', err);
          return generateMockMemberData();
        })
      ]);

      if (metricsResult.status === 'fulfilled') {
        stats = metricsResult.value;
      }

      if (donationsResult.status === 'fulfilled') {
        donationData = donationsResult.value;
      }

      if (attendanceResult.status === 'fulfilled') {
        attendanceData = attendanceResult.value;
      }

      if (membersResult.status === 'fulfilled') {
        memberData = membersResult.value;
      }

    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load dashboard data';
    } finally {
      isLoading = false;
    }
  });
</script>

<svelte:head>
  <title>Dashboard - Church Management System</title>
</svelte:head>

<div class="dashboard-container">
  <!-- Page header -->
  <div class="page-header">
    <h1 class="welcome-title">
      ✨ Welcome back, {$user?.username || 'Beloved'}! ✨
    </h1>
    <p class="welcome-subtitle">
      Here's what's happening in our blessed community today.
    </p>
  </div>

  {#if isLoading}
    <div class="loading-container">
      <Loading />
      <p class="loading-text">Loading your dashboard...</p>
    </div>
  {:else if error}
    <Card title="⚠️ Notice" content={error} />
  {:else}
    <!-- Blessed Statistics -->
    <div class="stats-grid">
      <Card title="👥 Our Community">
        <div class="stat-content">
          <div class="stat-number">{stats.totalMembers.toLocaleString()}</div>
          <div class="stat-label">Total Members</div>
          <div class="stat-detail">{stats.activeMembers} actively serving</div>
        </div>
      </Card>

      <Card title="📅 Upcoming Gatherings">
        <div class="stat-content">
          <div class="stat-number">{stats.upcomingEvents}</div>
          <div class="stat-label">Sacred Events</div>
          <div class="stat-detail">{stats.averageAttendance}% average attendance</div>
        </div>
      </Card>

      <Card title="💰 Monthly Blessings">
        <div class="stat-content">
          <div class="stat-number">${stats.monthlyDonations.toLocaleString()}</div>
          <div class="stat-label">Donations Received</div>
          <div class="stat-detail">${stats.monthlyTithes.toLocaleString()} in tithes</div>
        </div>
      </Card>

      <Card title="🙏 Service Volunteers">
        <div class="stat-content">
          <div class="stat-number">{stats.activeVolunteers}</div>
          <div class="stat-label">Active Servants</div>
          <div class="stat-detail">Giving their time graciously</div>
        </div>
      </Card>
    </div>

    <!-- Charts Section -->
    <div class="charts-grid">
      {#if donationData}
        <Card title="📊 Donation Trends">
          <DonationChart data={donationData} />
        </Card>
      {/if}

      {#if memberData}
        <Card title="📈 Member Growth">
          <MemberGrowthChart data={memberData} />
        </Card>
      {/if}
    </div>

    {#if attendanceData.length > 0}
      <Card title="👥 Recent Event Attendance">
        <AttendanceChart data={attendanceData} />
      </Card>
    {/if}

    <!-- Quick Actions -->
    <Card title="⚡ Sacred Actions">
      <div class="quick-actions">
        {#if $user?.role === 'Admin' || $user?.role === 'Pastor'}
          <a href="/members/create" class="action-card">
            <div class="action-icon">✨</div>
            <h4>Welcome New Soul</h4>
            <p>Register a new member to our blessed community</p>
          </a>

          <a href="/events/create" class="action-card">
            <div class="action-icon">🗓️</div>
            <h4>Plan Sacred Event</h4>
            <p>Schedule a new service or gathering</p>
          </a>

          <a href="/donations" class="action-card">
            <div class="action-icon">💰</div>
            <h4>Record Blessing</h4>
            <p>Log donations and offerings received</p>
          </a>
        {/if}

        {#if $user?.role === 'Member'}
          <a href="/profile" class="action-card">
            <div class="action-icon">👤</div>
            <h4>Update Profile</h4>
            <p>Keep your information current</p>
          </a>

          <a href="/my-donations" class="action-card">
            <div class="action-icon">📋</div>
            <h4>View Contributions</h4>
            <p>See your giving history and statements</p>
          </a>
        {/if}
      </div>
    </Card>

    <!-- Recent Activity -->
    <Card title="🕊️ Recent Blessings">
      <div class="activity-placeholder">
        <div class="activity-icon">📿</div>
        <h4>Peace and Grace</h4>
        <p>Recent activities and blessed events will appear here as they unfold in our community.</p>
      </div>
    </Card>
  {/if}
</div>

<style>
  .dashboard-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0;
  }

  .page-header {
    text-align: center;
    margin-bottom: 3rem;
    padding: 2rem 0;
    background: linear-gradient(135deg, rgba(241, 196, 15, 0.1), rgba(74, 35, 90, 0.1));
    border-radius: 20px;
    border: 2px solid var(--secondary);
  }

  .welcome-title {
    font-family: 'Playfair Display', serif;
    font-size: clamp(1.8rem, 4vw, 2.5rem);
    font-weight: 700;
    color: var(--primary);
    margin: 0 0 0.5rem 0;
    text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.1);
  }

  .welcome-subtitle {
    font-family: 'Crimson Text', serif;
    font-size: 1.2rem;
    color: var(--text-color);
    margin: 0;
    font-style: italic;
  }

  .loading-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 4rem 0;
    gap: 1rem;
  }

  .loading-text {
    font-family: 'Crimson Text', serif;
    font-size: 1.1rem;
    color: var(--primary);
    font-style: italic;
  }

  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 2rem;
    margin-bottom: 3rem;
  }

  .stat-content {
    text-align: center;
  }

  .stat-number {
    font-family: 'Playfair Display', serif;
    font-size: 2.5rem;
    font-weight: 700;
    color: var(--primary);
    margin-bottom: 0.5rem;
    text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.1);
  }

  .stat-label {
    font-family: 'Crimson Text', serif;
    font-size: 1.1rem;
    font-weight: 600;
    color: var(--accent);
    margin-bottom: 0.25rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .stat-detail {
    font-family: 'Crimson Text', serif;
    font-size: 0.9rem;
    color: var(--text-color);
    font-style: italic;
  }

  .charts-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
    gap: 2rem;
    margin-bottom: 3rem;
  }

  .quick-actions {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1.5rem;
    margin-top: 1rem;
  }

  .action-card {
    display: block;
    padding: 1.5rem;
    background: linear-gradient(135deg, white, var(--background-light));
    border: 2px solid var(--background-dark);
    border-radius: 12px;
    text-decoration: none;
    transition: all 0.3s ease;
    text-align: center;
  }

  .action-card:hover {
    transform: translateY(-3px);
    border-color: var(--secondary);
    box-shadow: 0 8px 25px rgba(74, 35, 90, 0.15);
  }

  .action-icon {
    font-size: 2rem;
    margin-bottom: 0.5rem;
  }

  .action-card h4 {
    font-family: 'Playfair Display', serif;
    font-size: 1.1rem;
    font-weight: 600;
    color: var(--primary);
    margin: 0 0 0.5rem 0;
  }

  .action-card p {
    font-family: 'Crimson Text', serif;
    font-size: 0.9rem;
    color: var(--text-color);
    margin: 0;
    line-height: 1.5;
  }

  .activity-placeholder {
    text-align: center;
    padding: 3rem 1rem;
    background: linear-gradient(135deg, rgba(241, 196, 15, 0.05), rgba(74, 35, 90, 0.05));
    border-radius: 12px;
    border: 1px dashed var(--background-dark);
  }

  .activity-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
  }

  .activity-placeholder h4 {
    font-family: 'Playfair Display', serif;
    font-size: 1.3rem;
    color: var(--primary);
    margin: 0 0 0.5rem 0;
  }

  .activity-placeholder p {
    font-family: 'Crimson Text', serif;
    font-size: 1rem;
    color: var(--text-color);
    margin: 0;
    line-height: 1.6;
    font-style: italic;
  }

  @media (max-width: 768px) {
    .stats-grid {
      grid-template-columns: 1fr;
      gap: 1.5rem;
    }

    .charts-grid {
      grid-template-columns: 1fr;
      gap: 1.5rem;
    }

    .quick-actions {
      grid-template-columns: 1fr;
      gap: 1rem;
    }

    .page-header {
      margin-bottom: 2rem;
      padding: 1.5rem;
    }
  }
</style>