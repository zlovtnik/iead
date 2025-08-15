<script lang="ts">
  import BaseChart from './BaseChart.svelte';
  import type { MemberReport } from '$lib/api/reports.js';

  interface Props {
    data: MemberReport;
    height?: number;
  }

  let { data, height = 400 }: Props = $props();

  const chartData = $derived.by(() => ({
    labels: data.membersByJoinDate.map(item => item.month),
    datasets: [
      {
        label: 'New Members',
        data: data.membersByJoinDate.map(item => item.count),
        backgroundColor: 'rgba(139, 92, 246, 0.5)',
        borderColor: 'rgb(139, 92, 246)',
        borderWidth: 2,
        fill: true,
      },
    ],
  }));

  const chartOptions = $derived.by(() => ({
    plugins: {
      title: {
        display: true,
        text: 'Member Growth Over Time',
      },
    },
    scales: {
      y: {
        beginAtZero: true,
        title: {
          display: true,
          text: 'Number of New Members',
        },
      },
      x: {
        title: {
          display: true,
          text: 'Month',
        },
      },
    },
  }));
</script>

<BaseChart type="line" data={chartData} options={chartOptions} {height} />