<script lang="ts">
  import BaseChart from './BaseChart.svelte';
  import type { AttendanceReport } from '$lib/api/reports.js';

  interface Props {
    data: AttendanceReport[];
    height?: number;
  }

  let { data, height = 400 }: Props = $props();

  const chartData = $derived.by(() => ({
    labels: data.map(item => item.eventTitle),
    datasets: [
      {
        label: 'Attendance',
        data: data.map(item => item.totalAttendees),
        backgroundColor: 'rgba(16, 185, 129, 0.5)',
        borderColor: 'rgb(16, 185, 129)',
        borderWidth: 2,
      },
      {
        label: 'Attendance Rate (%)',
        data: data.map(item => item.attendanceRate),
        backgroundColor: 'rgba(245, 158, 11, 0.5)',
        borderColor: 'rgb(245, 158, 11)',
        borderWidth: 2,
        yAxisID: 'y1',
      },
    ],
  }));

  const chartOptions = $derived.by(() => ({
    plugins: {
      title: {
        display: true,
        text: 'Event Attendance Overview',
      },
    },
    scales: {
      y: {
        type: 'linear' as const,
        display: true,
        position: 'left' as const,
        beginAtZero: true,
        title: {
          display: true,
          text: 'Number of Attendees',
        },
      },
      y1: {
        type: 'linear' as const,
        display: true,
        position: 'right' as const,
        beginAtZero: true,
        max: 100,
        title: {
          display: true,
          text: 'Attendance Rate (%)',
        },
        grid: {
          drawOnChartArea: false,
        },
      },
    },
  }));
</script>

<BaseChart type="bar" data={chartData} options={chartOptions} {height} />