<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements';
  
  interface Props extends HTMLInputAttributes {
    label?: string;
    error?: string;
    helperText?: string;
    required?: boolean;
    fullWidth?: boolean;
    leftIcon?: any;
    rightIcon?: any;
    oninput?: (event: Event) => void;
  }
  
  let {
    label,
    error,
    helperText,
    required = false,
    fullWidth = false,
    leftIcon,
    rightIcon,
    class: className = '',
    id,
    ...restProps
  }: Props = $props();
  
  // Generate unique ID if not provided
  const inputId = id || `input-${Math.random().toString(36).substr(2, 9)}`;
  
  const baseInputClasses = 'block px-3 py-2 border rounded-lg shadow-sm transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-offset-1 disabled:opacity-50 disabled:cursor-not-allowed';
  
  const normalClasses = 'border-secondary-300 focus:border-primary-500 focus:ring-primary-500';
  const errorClasses = 'border-error-300 focus:border-error-500 focus:ring-error-500';
  
  const widthClass = fullWidth ? 'w-full' : '';
  const paddingClasses = leftIcon ? 'pl-10' : rightIcon ? 'pr-10' : '';
  
  const inputClasses = `${baseInputClasses} ${error ? errorClasses : normalClasses} ${widthClass} ${paddingClasses} ${className}`;
</script>

<div class={fullWidth ? 'w-full' : ''}>
  {#if label}
    <label for={inputId} class="block text-sm font-medium text-secondary-700 mb-1">
      {label}
      {#if required}
        <span class="text-error-500 ml-1">*</span>
      {/if}
    </label>
  {/if}
  
  <div class="relative">
    {#if leftIcon}
      <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
        <div class="h-5 w-5 text-secondary-400">
          {@render leftIcon()}
        </div>
      </div>
    {/if}
    
    <input
      {id}
      class={inputClasses}
      aria-invalid={error ? 'true' : 'false'}
      aria-describedby={error ? `${inputId}-error` : helperText ? `${inputId}-helper` : undefined}
      {...restProps}
    />
    
    {#if rightIcon}
      <div class="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
        <div class="h-5 w-5 text-secondary-400">
          {@render rightIcon()}
        </div>
      </div>
    {/if}
  </div>
  
  {#if error}
    <p id="{inputId}-error" class="mt-1 text-sm text-error-600" role="alert">
      {error}
    </p>
  {:else if helperText}
    <p id="{inputId}-helper" class="mt-1 text-sm text-secondary-500">
      {helperText}
    </p>
  {/if}
</div>