<script lang="ts">
  import BaseChart from './BaseChart.svelte';
  import type { DonationSummary } from '$lib/api/reports.js';

  interface Props {
    data: DonationSummary;
    type?: 'monthly' | 'category';
    height?: number;
  }

  let { data, type = 'monthly', height = 400 }: Props = $props();

  const chartData = $derived.by(() => {
    if (type === 'monthly') {
      return {
        labels: data.donationsByMonth.map(item => item.month),
        datasets: [
          {
            label: 'Donations ($)',
            data: data.donationsByMonth.map(item => item.amount),
            backgroundColor: 'rgba(59, 130, 246, 0.5)',
            borderColor: 'rgb(59, 130, 246)',
            borderWidth: 2,
            fill: true,
          },
        ],
      };
    } else {
      return {
        labels: data.donationsByCategory.map(item => item.category),
        datasets: [
          {
            label: 'Amount ($)',
            data: data.donationsByCategory.map(item => item.amount),
            backgroundColor: [
              'rgba(59, 130, 246, 0.8)',
              'rgba(16, 185, 129, 0.8)',
              'rgba(245, 158, 11, 0.8)',
              'rgba(239, 68, 68, 0.8)',
              'rgba(139, 92, 246, 0.8)',
            ],
            borderWidth: 1,
          },
        ],
      };
    }
  });

  const chartOptions = $derived.by(() => ({
    plugins: {
      title: {
        display: true,
        text: type === 'monthly' ? 'Monthly Donations' : 'Donations by Category',
      },
      legend: {
        display: type === 'category',
      },
    },
    scales: type === 'category' ? undefined : {
      y: {
        beginAtZero: true,
        ticks: {
          callback: function(value: any) {
            return '$' + value.toLocaleString();
          }
        }
      }
    }
  }));
</script>

<BaseChart 
  type={type === 'monthly' ? 'line' : 'doughnut'} 
  data={chartData} 
  options={chartOptions} 
  {height} 
/>