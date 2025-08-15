<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { Chart, registerables } from 'chart.js';
  import 'chartjs-adapter-date-fns';

  interface Props {
    type: 'line' | 'bar' | 'doughnut' | 'pie';
    data: any;
    options?: any;
    height?: number;
    width?: number;
  }

  let { type, data, options = {}, height = 400, width }: Props = $props();

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  // Register Chart.js components
  Chart.register(...registerables);

  const defaultOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top' as const,
      },
      tooltip: {
        mode: 'index' as const,
        intersect: false,
      },
    },
    scales: type === 'doughnut' || type === 'pie' ? undefined : {
      x: {
        display: true,
        grid: {
          display: false,
        },
      },
      y: {
        display: true,
        beginAtZero: true,
        grid: {
          color: 'rgba(0, 0, 0, 0.1)',
        },
      },
    },
  };

  onMount(() => {
    if (canvas) {
      chart = new Chart(canvas, {
        type,
        data,
        options: { ...defaultOptions, ...options },
      });
    }
  });

  onDestroy(() => {
    if (chart) {
      chart.destroy();
    }
  });

  // Update chart when data changes
  $effect(() => {
    if (chart && data) {
      chart.data = data;
      chart.update();
    }
  });

  // Update chart when options change
  $effect(() => {
    if (chart && options) {
      chart.options = { ...defaultOptions, ...options };
      chart.update();
    }
  });
</script>

<div class="chart-container" style="height: {height}px; {width ? `width: ${width}px;` : ''}">
  <canvas bind:this={canvas}></canvas>
</div>

<style>
  .chart-container {
    position: relative;
  }
</style>