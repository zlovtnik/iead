<script lang="ts">
  import type { HTMLInputAttributes, HTMLTextareaAttributes, HTMLSelectAttributes } from 'svelte/elements';
  import Input from '../ui/Input.svelte';
  
  interface BaseProps {
    name: string;
    label?: string;
    error?: string;
    helperText?: string;
    required?: boolean;
    disabled?: boolean;
    readonly?: boolean;
    fullWidth?: boolean;
    onchange?: (value: any) => void;
    onblur?: (event: FocusEvent) => void;
    onfocus?: (event: FocusEvent) => void;
  }
  
  interface InputProps extends BaseProps, Omit<HTMLInputAttributes, 'name' | 'onchange' | 'onblur' | 'onfocus'> {
    type?: 'text' | 'email' | 'password' | 'number' | 'tel' | 'url' | 'search' | 'date' | 'datetime-local' | 'time';
    leftIcon?: any;
    rightIcon?: any;
  }
  
  interface TextareaProps extends BaseProps, Omit<HTMLTextareaAttributes, 'name' | 'onchange' | 'onblur' | 'onfocus'> {
    type: 'textarea';
    rows?: number;
    resize?: boolean;
  }
  
  interface SelectProps extends BaseProps, Omit<HTMLSelectAttributes, 'name' | 'onchange' | 'onblur' | 'onfocus'> {
    type: 'select';
    options: Array<{ value: string | number; label: string; disabled?: boolean }>;
    placeholder?: string;
  }
  
  type Props = InputProps | TextareaProps | SelectProps;
  
  let {
    name,
    label,
    error,
    helperText,
    required = false,
    disabled = false,
    readonly = false,
    fullWidth = false,
    type = 'text',
    value = $bindable(),
    class: className = '',
    onchange,
    onblur,
    onfocus,
    ...restProps
  }: Props = $props();
  
  // Generate unique ID for accessibility
  const fieldId = `field-${name}-${Math.random().toString(36).slice(2, 9)}`;
  const errorId = `${fieldId}-error`;
  const helperId = `${fieldId}-helper`;
  
  // Handle value changes
  function handleChange(event: Event) {
    const target = event.target as HTMLInputElement | HTMLTextareaElement | HTMLSelectElement;
    let newValue: any = target.value;
    
    // Convert number inputs to actual numbers
    if (type === 'number' && newValue !== '') {
      newValue = parseFloat(newValue);
      if (isNaN(newValue)) newValue = '';
    }
    
    value = newValue;
    onchange?.(newValue);
  }
  
  function handleBlur(event: FocusEvent) {
    onblur?.(event);
  }
  
  function handleFocus(event: FocusEvent) {
    onfocus?.(event);
  }
  
  // Base classes for form elements
  const baseClasses = 'block w-full px-3 py-2 border rounded-lg shadow-sm transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-offset-1 disabled:opacity-50 disabled:cursor-not-allowed read-only:bg-secondary-50 read-only:cursor-default';
  const normalClasses = 'border-secondary-300 focus:border-primary-500 focus:ring-primary-500';
  const errorClasses = 'border-error-300 focus:border-error-500 focus:ring-error-500';
  
  const inputClasses = `${baseClasses} ${error ? errorClasses : normalClasses} ${className}`;
</script>

<div class={fullWidth ? 'w-full' : ''}>
  {#if label}
    <label for={fieldId} class="block text-sm font-medium text-secondary-700 mb-1">
      {label}
      {#if required}
        <span class="text-error-500 ml-1" aria-label="required">*</span>
      {/if}
    </label>
  {/if}
  
  {#if type === 'textarea'}
    <textarea
      id={fieldId}
      {name}
      bind:value
      class={inputClasses}
      {disabled}
      {readonly}
      {required}
      rows={restProps.rows || 3}
      style:resize={restProps.resize === false ? 'none' : 'vertical'}
      aria-invalid={error ? 'true' : 'false'}
      aria-describedby={error ? errorId : helperText ? helperId : undefined}
      onchange={handleChange}
      onblur={handleBlur}
      onfocus={handleFocus}
      {...restProps}
    ></textarea>
  {:else if type === 'select'}
    <select
      id={fieldId}
      {name}
      bind:value
      class={inputClasses}
      {disabled}
      {readonly}
      {required}
      aria-invalid={error ? 'true' : 'false'}
      aria-describedby={error ? errorId : helperText ? helperId : undefined}
      onchange={handleChange}
      onblur={handleBlur}
      onfocus={handleFocus}
      {...restProps}
    >
      {#if restProps.placeholder}
        <option value="" disabled selected={!value}>
          {restProps.placeholder}
        </option>
      {/if}
      {#each restProps.options as option}
        <option value={option.value} disabled={option.disabled}>
          {option.label}
        </option>
      {/each}
    </select>
  {:else}
    <div class="relative">
      {#if restProps.leftIcon}
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
          <div class="h-5 w-5 text-secondary-400">
            {@render restProps.leftIcon()}
          </div>
        </div>
      {/if}
      
      <input
        id={fieldId}
        {name}
        {type}
        bind:value
        class={`${inputClasses} ${restProps.leftIcon ? 'pl-10' : ''} ${restProps.rightIcon ? 'pr-10' : ''}`}
        {disabled}
        {readonly}
        {required}
        aria-invalid={error ? 'true' : 'false'}
        aria-describedby={error ? errorId : helperText ? helperId : undefined}
        onchange={handleChange}
        onblur={handleBlur}
        onfocus={handleFocus}
        {...restProps}
      />
      
      {#if restProps.rightIcon}
        <div class="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
          <div class="h-5 w-5 text-secondary-400">
            {@render restProps.rightIcon()}
          </div>
        </div>
      {/if}
    </div>
  {/if}
  
  {#if error}
    <p id={errorId} class="mt-1 text-sm text-error-600" role="alert">
      {error}
    </p>
  {:else if helperText}
    <p id={helperId} class="mt-1 text-sm text-secondary-500">
      {helperText}
    </p>
  {/if}
</div>