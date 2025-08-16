<script lang="ts">
  import { toastStore } from '$lib/stores/ui';
  import Toast from './Toast.svelte';
  
  const toasts = toastStore.toasts;
</script>

<div class="fixed top-4 right-4 z-50 space-y-4">
  {#each $toasts as toast (toast.id)}
    <div class="transform transition-all duration-300 ease-in-out">
      <Toast
        type={toast.type}
        title={toast.title}
        message={toast.message}
        duration={toast.duration}
        closable={toast.closable}
        show={toast.show}
        on:close={() => toastStore.remove(toast.id)}
      />
    </div>
  {/each}
</div>