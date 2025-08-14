<script lang="ts">
  interface Props {
    width?: string;
    height?: string;
    rounded?: boolean;
    lines?: number;
    class?: string;
  }
  
  let {
    width = 'w-full',
    height = 'h-4',
    rounded = false,
    lines = 1,
    class: className = ''
  }: Props = $props();
  
  const baseClasses = 'animate-pulse bg-secondary-200';
  const roundedClass = rounded ? 'rounded-full' : 'rounded';
  const skeletonClasses = `${baseClasses} ${width} ${height} ${roundedClass} ${className}`;
</script>

{#if lines === 1}
  <div class={skeletonClasses}></div>
{:else}
  <div class="space-y-2">
    {#each Array(lines) as _, i}
      <div class={skeletonClasses} style="width: {i === lines - 1 ? '75%' : '100%'}"></div>
    {/each}
  </div>
{/if}