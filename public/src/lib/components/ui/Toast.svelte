<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  
  interface Props {
    type?: 'success' | 'error' | 'warning' | 'info';
    title?: string;
    message: string;
    duration?: number;
    closable?: boolean;
    show?: boolean;
  }
  
  let {
    type = 'info',
    title,
    message,
    duration = 5000,
    closable = true,
    show = true
  }: Props = $props();
  
  const dispatch = createEventDispatcher<{
    close: void;
  }>();
  
  let timeoutId: ReturnType<typeof setTimeout>;
  
  const typeConfig = {
    success: {
      bgColor: 'bg-success-50',
      borderColor: 'border-success-200',
      textColor: 'text-success-800',
      iconColor: 'text-success-400',
      icon: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />`
    },
    error: {
      bgColor: 'bg-error-50',
      borderColor: 'border-error-200',
      textColor: 'text-error-800',
      iconColor: 'text-error-400',
      icon: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />`
    },
    warning: {
      bgColor: 'bg-warning-50',
      borderColor: 'border-warning-200',
      textColor: 'text-warning-800',
      iconColor: 'text-warning-400',
      icon: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />`
    },
    info: {
      bgColor: 'bg-primary-50',
      borderColor: 'border-primary-200',
      textColor: 'text-primary-800',
      iconColor: 'text-primary-400',
      icon: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />`
    }
  };
  
  const config = typeConfig[type];
  
  function handleClose() {
    show = false;
    dispatch('close');
  }
  
  onMount(() => {
    if (duration > 0) {
      timeoutId = setTimeout(() => {
        handleClose();
      }, duration);
    }
    
    return () => {
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
    };
  });
</script>

{#if show}
  <div
    class="max-w-sm w-full {config.bgColor} {config.borderColor} border rounded-lg shadow-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden"
    role="alert"
    aria-live="assertive"
    aria-atomic="true"
  >
    <div class="p-4">
      <div class="flex items-start">
        <div class="flex-shrink-0">
          <svg class="h-6 w-6 {config.iconColor}" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            {@html config.icon}
          </svg>
        </div>
        
        <div class="ml-3 w-0 flex-1 pt-0.5">
          {#if title}
            <p class="text-sm font-medium {config.textColor}">
              {title}
            </p>
          {/if}
          <p class="text-sm {config.textColor} {title ? 'mt-1' : ''}">
            {message}
          </p>
        </div>
        
        {#if closable}
          <div class="ml-4 flex-shrink-0 flex">
            <button
              type="button"
              class="bg-white rounded-md inline-flex text-secondary-400 hover:text-secondary-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
              onclick={handleClose}
              aria-label="Close notification"
            >
              <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
              </svg>
            </button>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}