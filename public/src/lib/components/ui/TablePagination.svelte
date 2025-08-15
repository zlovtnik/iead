<script lang="ts">
  import type { TablePagination } from '../../types/table.js';
  import Button from './Button.svelte';

  interface Props {
    pagination: TablePagination;
    pageSizeOptions?: number[];
    showPageSizeSelector?: boolean;
    showPageInfo?: boolean;
    maxVisiblePages?: number;
    onpaginate?: (pagination: Partial<TablePagination>) => void;
  }

  let {
    pagination,
    pageSizeOptions = [10, 25, 50, 100],
    showPageSizeSelector = true,
    showPageInfo = true,
    maxVisiblePages = 5,
    onpaginate
  }: Props = $props();

  function goToPage(page: number) {
    if (page < 1 || page > pagination.totalPages || page === pagination.page) {
      return;
    }
    
    onpaginate?.({ page });
  }

  function changePageSize(pageSize: number) {
    if (pageSize === pagination.pageSize) return;
    
    // Calculate new page to maintain roughly the same position
    const currentFirstItem = (pagination.page - 1) * pagination.pageSize + 1;
    const newPage = Math.ceil(currentFirstItem / pageSize);
    
    onpaginate?.({ 
      pageSize, 
      page: Math.min(newPage, Math.ceil(pagination.total / pageSize))
    });
  }

  function getVisiblePages(): number[] {
    const { page, totalPages } = pagination;
    const pages: number[] = [];
    
    if (totalPages <= maxVisiblePages) {
      // Show all pages if total is less than max
      for (let i = 1; i <= totalPages; i++) {
        pages.push(i);
      }
    } else {
      // Calculate range around current page
      const halfVisible = Math.floor(maxVisiblePages / 2);
      let start = Math.max(1, page - halfVisible);
      let end = Math.min(totalPages, start + maxVisiblePages - 1);
      
      // Adjust start if we're near the end
      if (end - start + 1 < maxVisiblePages) {
        start = Math.max(1, end - maxVisiblePages + 1);
      }
      
      for (let i = start; i <= end; i++) {
        pages.push(i);
      }
    }
    
    return pages;
  }

  let visiblePages = $derived(getVisiblePages());
  let startItem = $derived((pagination.page - 1) * pagination.pageSize + 1);
  let endItem = $derived(Math.min(pagination.page * pagination.pageSize, pagination.total));
  let hasPrevious = $derived(pagination.page > 1);
  let hasNext = $derived(pagination.page < pagination.totalPages);
</script>

<div class="bg-white px-4 py-3 flex items-center justify-between border-t border-gray-200 sm:px-6">
  <!-- Mobile pagination -->
  <div class="flex-1 flex justify-between sm:hidden">
    <Button
      variant="secondary"
      size="sm"
      disabled={!hasPrevious}
      onclick={() => goToPage(pagination.page - 1)}
    >
      Previous
    </Button>
    <Button
      variant="secondary"
      size="sm"
      disabled={!hasNext}
      onclick={() => goToPage(pagination.page + 1)}
    >
      Next
    </Button>
  </div>

  <!-- Desktop pagination -->
  <div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
    <div class="flex items-center space-x-4">
      {#if showPageInfo}
        <p class="text-sm text-gray-700">
          Showing <span class="font-medium">{startItem}</span> to 
          <span class="font-medium">{endItem}</span> of 
          <span class="font-medium">{pagination.total}</span> results
        </p>
      {/if}
      
      {#if showPageSizeSelector}
        <div class="flex items-center space-x-2">
          <label for="pageSize" class="text-sm text-gray-700">Show:</label>
          <select
            id="pageSize"
            value={pagination.pageSize}
            onchange={(e) => changePageSize(Number(e.currentTarget.value))}
            class="border-gray-300 rounded-md text-sm focus:ring-blue-500 focus:border-blue-500"
          >
            {#each pageSizeOptions as option}
              <option value={option}>{option}</option>
            {/each}
          </select>
        </div>
      {/if}
    </div>

    <div>
      <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px" aria-label="Pagination">
        <!-- Previous button -->
        <button
          onclick={() => goToPage(pagination.page - 1)}
          disabled={!hasPrevious}
          class="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed focus:z-10 focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
          aria-label="Previous page"
        >
          <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
            <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" />
          </svg>
        </button>

        <!-- Page numbers -->
        {#each visiblePages as pageNum}
          <button
            onclick={() => goToPage(pageNum)}
            class="relative inline-flex items-center px-4 py-2 border text-sm font-medium focus:z-10 focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 {pageNum === pagination.page
              ? 'z-10 bg-blue-50 border-blue-500 text-blue-600'
              : 'bg-white border-gray-300 text-gray-500 hover:bg-gray-50'}"
            aria-label="Page {pageNum}"
            aria-current={pageNum === pagination.page ? 'page' : undefined}
          >
            {pageNum}
          </button>
        {/each}

        <!-- Show ellipsis and last page if needed -->
        {#if visiblePages[visiblePages.length - 1] < pagination.totalPages - 1}
          <span class="relative inline-flex items-center px-4 py-2 border border-gray-300 bg-white text-sm font-medium text-gray-700">
            ...
          </span>
          <button
            onclick={() => goToPage(pagination.totalPages)}
            class="relative inline-flex items-center px-4 py-2 border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 focus:z-10 focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
            aria-label="Last page, page {pagination.totalPages}"
          >
            {pagination.totalPages}
          </button>
        {/if}

        <!-- Next button -->
        <button
          onclick={() => goToPage(pagination.page + 1)}
          disabled={!hasNext}
          class="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed focus:z-10 focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
          aria-label="Next page"
        >
          <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
            <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" />
          </svg>
        </button>
      </nav>
    </div>
  </div>
</div>