<script lang="ts">
  import type { TableColumn, TableSort, SortDirection } from '../../types/table.js';

  interface Props {
    columns: TableColumn[];
    sort?: TableSort;
    selectable?: boolean;
    allSelected?: boolean;
    someSelected?: boolean;
    onsort?: (sort: TableSort) => void;
    onselectAll?: (selected: boolean) => void;
  }

  let {
    columns,
    sort = { column: '', direction: null },
    selectable = false,
    allSelected = false,
    someSelected = false,
    onsort,
    onselectAll
  }: Props = $props();

  function handleSort(column: TableColumn) {
    if (!column.sortable) return;

    let direction: SortDirection = 'asc';
    
    if (sort.column === column.key) {
      if (sort.direction === 'asc') {
        direction = 'desc';
      } else if (sort.direction === 'desc') {
        direction = null;
      }
    }

    onsort?.({
      column: column.key,
      direction
    });
  }

  function handleSelectAll() {
    onselectAll?.(!allSelected);
  }

  function getSortIcon(column: TableColumn): string {
    if (!column.sortable) return '';
    
    if (sort.column !== column.key) {
      return 'M7 10l5 5 5-5z'; // Unsorted icon
    }
    
    if (sort.direction === 'asc') {
      return 'M7 14l5-5 5 5z'; // Up arrow
    } else if (sort.direction === 'desc') {
      return 'M7 10l5 5 5-5z'; // Down arrow
    }
    
    return 'M7 10l5 5 5-5z'; // Default
  }

  function getColumnClass(column: TableColumn): string {
    const baseClass = 'px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider';
    const alignClass = column.align === 'center' ? 'text-center' : 
                      column.align === 'right' ? 'text-right' : 'text-left';
    const sortableClass = column.sortable ? 'cursor-pointer hover:bg-gray-50 select-none' : '';
    const customClass = column.className || '';
    
    return `${baseClass} ${alignClass} ${sortableClass} ${customClass}`.trim();
  }
</script>

<thead class="bg-gray-50">
  <tr>
    {#if selectable}
      <th class="px-6 py-3 text-left">
        <input
          type="checkbox"
          checked={allSelected}
          indeterminate={someSelected && !allSelected}
          onchange={handleSelectAll}
          class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
          aria-label="Select all rows"
        />
      </th>
    {/if}
    
    {#each columns as column}
      <th
        class={getColumnClass(column)}
        style={column.width ? `width: ${column.width}` : ''}
        onclick={() => handleSort(column)}
        role={column.sortable ? 'button' : undefined}
        tabindex={column.sortable ? 0 : undefined}
        onkeydown={(e) => {
          if (column.sortable && (e.key === 'Enter' || e.key === ' ')) {
            e.preventDefault();
            handleSort(column);
          }
        }}
        aria-sort={
          sort.column === column.key
            ? sort.direction === 'asc'
              ? 'ascending'
              : sort.direction === 'desc'
              ? 'descending'
              : 'none'
            : column.sortable
            ? 'none'
            : undefined
        }
      >
        <div class="flex items-center space-x-1">
          <span>{column.label}</span>
          {#if column.sortable}
            <svg
              class="w-4 h-4 {sort.column === column.key ? 'text-gray-900' : 'text-gray-400'}"
              fill="currentColor"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path d={getSortIcon(column)} />
            </svg>
          {/if}
        </div>
      </th>
    {/each}
    
    <!-- Actions column header if needed -->
    <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
      Actions
    </th>
  </tr>
</thead>