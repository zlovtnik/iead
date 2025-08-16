<script lang="ts">
  import { Button, Input, Modal, Loading, Skeleton, ToastContainer } from '$lib/components/ui';
  import { toastStore } from '$lib/stores/ui';
  
  let showModal = $state(false);
  let inputValue = $state('');
  let inputError = $state('');
  let loading = $state(false);
  
  function handleButtonClick() {
    toastStore.success('Button clicked!', 'Success');
  }
  
  function handleInputChange(event: Event) {
    const target = event.target as HTMLInputElement;
    inputValue = target.value;
    
    if (inputValue.length < 3) {
      inputError = 'Input must be at least 3 characters';
    } else {
      inputError = '';
    }
  }
  
  function toggleLoading() {
    loading = !loading;
    setTimeout(() => {
      loading = false;
    }, 3000);
  }
  
  function showToasts() {
    toastStore.success('Success message', 'Success');
    setTimeout(() => toastStore.error('Error message', 'Error'), 500);
    setTimeout(() => toastStore.warning('Warning message', 'Warning'), 1000);
    setTimeout(() => toastStore.info('Info message', 'Info'), 1500);
  }
</script>

<svelte:head>
  <title>UI Components Demo</title>
</svelte:head>

<div class="container mx-auto p-8 space-y-8">
  <h1 class="text-3xl font-bold text-secondary-900 mb-8">UI Components Demo</h1>
  
  <!-- Button Examples -->
  <section class="space-y-4">
    <h2 class="text-2xl font-semibold text-secondary-800">Buttons</h2>
    <div class="flex flex-wrap gap-4">
      <Button variant="primary" onclick={handleButtonClick}>Primary</Button>
      <Button variant="secondary">Secondary</Button>
      <Button variant="success">Success</Button>
      <Button variant="warning">Warning</Button>
      <Button variant="error">Error</Button>
      <Button variant="ghost">Ghost</Button>
      <Button variant="outline">Outline</Button>
    </div>
    
    <div class="flex flex-wrap gap-4">
      <Button size="sm">Small</Button>
      <Button size="md">Medium</Button>
      <Button size="lg">Large</Button>
    </div>
    
    <div class="flex flex-wrap gap-4">
      <Button loading={true}>Loading</Button>
      <Button disabled={true}>Disabled</Button>
      <Button fullWidth={true}>Full Width</Button>
    </div>
  </section>
  
  <!-- Input Examples -->
  <section class="space-y-4">
    <h2 class="text-2xl font-semibold text-secondary-800">Inputs</h2>
    <div class="max-w-md space-y-4">
      <Input 
        label="Basic Input" 
        placeholder="Enter some text"
        value={inputValue}
        oninput={handleInputChange}
        error={inputError}
      />
      
      <Input 
        label="Required Input" 
        placeholder="This field is required"
        required={true}
      />
      
      <Input 
        label="Input with Helper Text" 
        placeholder="Enter your email"
        helperText="We'll never share your email with anyone else."
        type="email"
      />
      
      <Input 
        label="Full Width Input" 
        placeholder="This input takes full width"
        fullWidth={true}
      />
    </div>
  </section>
  
  <!-- Modal Example -->
  <section class="space-y-4">
    <h2 class="text-2xl font-semibold text-secondary-800">Modal</h2>
    <Button onclick={() => showModal = true}>Open Modal</Button>
    
    <Modal open={showModal} title="Demo Modal" size="md">
      <p class="text-secondary-600">
        This is a demo modal with a title and some content. You can close it by clicking the X button or pressing Escape.
      </p>
      
      {#snippet footer()}
        <div class="flex justify-end space-x-2">
          <Button variant="ghost" onclick={() => showModal = false}>Cancel</Button>
          <Button variant="primary" onclick={() => showModal = false}>Confirm</Button>
        </div>
      {/snippet}
    </Modal>
  </section>
  
  <!-- Loading Examples -->
  <section class="space-y-4">
    <h2 class="text-2xl font-semibold text-secondary-800">Loading</h2>
    <div class="flex flex-wrap gap-4 items-center">
      <Loading size="sm" />
      <Loading size="md" />
      <Loading size="lg" />
      <Loading size="xl" />
    </div>
    
    <div class="flex flex-wrap gap-4 items-center">
      <Loading size="md" text="Loading..." />
      <Loading size="md" color="secondary" text="Processing..." />
    </div>
    
    <Button onclick={toggleLoading}>Toggle Overlay Loading</Button>
    
    {#if loading}
      <Loading overlay={true} text="Loading overlay..." />
    {/if}
  </section>
  
  <!-- Skeleton Examples -->
  <section class="space-y-4">
    <h2 class="text-2xl font-semibold text-secondary-800">Skeleton</h2>
    <div class="max-w-md space-y-4">
      <Skeleton />
      <Skeleton lines={3} />
      <Skeleton width="w-32" height="h-8" rounded={true} />
      <div class="flex items-center space-x-4">
        <Skeleton width="w-12" height="h-12" rounded={true} />
        <div class="flex-1">
          <Skeleton lines={2} />
        </div>
      </div>
    </div>
  </section>
  
  <!-- Toast Examples -->
  <section class="space-y-4">
    <h2 class="text-2xl font-semibold text-secondary-800">Toasts</h2>
    <Button onclick={showToasts}>Show All Toast Types</Button>
  </section>
</div>

<ToastContainer />