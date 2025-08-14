<script lang="ts">
  interface Props {
    error?: string | string[];
    class?: string;
  }
  
  let {
    error,
    class: className = ''
  }: Props = $props();
  
  const errors = $derived(() => {
    if (!error) return [];
    return Array.isArray(error) ? error : [error];
  });
</script>

{#if errors.length > 0}
  <div class={`text-sm text-error-600 ${className}`} role="alert">
    {#if errors.length === 1}
      <p>{errors[0]}</p>
    {:else}
      <ul class="list-disc list-inside space-y-1">
        {#each errors as errorMessage}
          <li>{errorMessage}</li>
        {/each}
      </ul>
    {/if}
  </div>
{/if}