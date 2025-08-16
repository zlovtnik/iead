<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { browser } from '$app/environment';
  
  interface Props {
    open?: boolean;
    title?: string;
    size?: 'sm' | 'md' | 'lg' | 'xl' | 'full';
    closable?: boolean;
    children?: any;
    footer?: any;
  }
  
  let {
    open = false,
    title,
    size = 'md',
    closable = true,
    children,
    footer
  }: Props = $props();
  
  const dispatch = createEventDispatcher<{
    close: void;
    open: void;
  }>();
  
  let modalElement = $state<HTMLDivElement>();
  let previousActiveElement: Element | null = null;
  
  const sizeClasses = {
    sm: 'max-w-md',
    md: 'max-w-lg',
    lg: 'max-w-2xl',
    xl: 'max-w-4xl',
    full: 'max-w-full mx-4'
  };
  
  function handleClose() {
    if (closable) {
      dispatch('close');
    }
  }
  
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      handleClose();
    }
    
    // Trap focus within modal
    if (event.key === 'Tab') {
      const focusableElements = modalElement?.querySelectorAll(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      );
      
      if (focusableElements && focusableElements.length > 0) {
        const firstElement = focusableElements[0] as HTMLElement;
        const lastElement = focusableElements[focusableElements.length - 1] as HTMLElement;
        
        if (event.shiftKey && document.activeElement === firstElement) {
          event.preventDefault();
          lastElement.focus();
        } else if (!event.shiftKey && document.activeElement === lastElement) {
          event.preventDefault();
          firstElement.focus();
        }
      }
    }
  }
  
  function handleBackdropClick(event: MouseEvent) {
    if (event.target === event.currentTarget) {
      handleClose();
    }
  }
  
  function handleBackdropKeydown(event: KeyboardEvent) {
    // Handle keydown events on backdrop if needed
  }
  
  $effect(() => {
    if (browser) {
      if (open) {
        // Store the previously focused element
        previousActiveElement = document.activeElement;
        
        // Prevent body scroll
        document.body.style.overflow = 'hidden';
        
        // Focus the modal
        setTimeout(() => {
          const firstFocusable = modalElement?.querySelector(
            'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
          ) as HTMLElement;
          
          if (firstFocusable) {
            firstFocusable.focus();
          } else {
            modalElement?.focus();
          }
        }, 100);
        
        dispatch('open');
      } else {
        // Restore body scroll
        document.body.style.overflow = '';
        
        // Restore focus to previously focused element
        if (previousActiveElement instanceof HTMLElement) {
          previousActiveElement.focus();
        }
      }
    }
  });
  
  onMount(() => {
    return () => {
      if (browser) {
        document.body.style.overflow = '';
      }
    };
  });
</script>

<svelte:window on:keydown={handleKeydown} />

{#if open}
  <div
    class="fixed inset-0 z-50 overflow-y-auto"
    aria-labelledby={title ? 'modal-title' : undefined}
    aria-modal="true"
    role="dialog"
  >
    <!-- Backdrop -->
    <div
      class="fixed inset-0 bg-secondary-900 bg-opacity-50 transition-opacity"
      onclick={handleBackdropClick}
      onkeydown={handleBackdropKeydown}
      role="presentation"
    ></div>
    
    <!-- Modal -->
    <div class="flex min-h-full items-center justify-center p-4">
      <div
        bind:this={modalElement}
        class="relative w-full {sizeClasses[size]} transform overflow-hidden rounded-lg bg-white shadow-xl transition-all"
        tabindex="-1"
      >
        <!-- Header -->
        {#if title || closable}
          <div class="flex items-center justify-between px-6 py-4 border-b border-secondary-200">
            {#if title}
              <h3 id="modal-title" class="text-lg font-semibold text-secondary-900">
                {title}
              </h3>
            {/if}
            
            {#if closable}
              <button
                type="button"
                class="rounded-md text-secondary-400 hover:text-secondary-600 focus:outline-none focus:ring-2 focus:ring-primary-500"
                onclick={handleClose}
                aria-label="Close modal"
              >
                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            {/if}
          </div>
        {/if}
        
        <!-- Content -->
        <div class="px-6 py-4">
          {@render children?.()}
        </div>
        
        <!-- Footer -->
        {#if footer}
          <div class="px-6 py-4 border-t border-secondary-200 bg-secondary-50">
            {@render footer()}
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}