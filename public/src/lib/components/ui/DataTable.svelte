<script lang="ts">
  import type { 
    TableColumn, 
    TableSort, 
    TableFilter, 
    TablePagination, 
    TableAction,
    TableConfig 
  } from '../../types/table.js';
  import type { User } from '../../api/auth.js';

  import { hasPermission } from '../../utils/permissions.js';
  import TableHeader from './TableHeader.svelte';
  import TablePaginationComponent from './TablePagination.svelte';
  import Button from './Button.svelte';
  import Loading from './Loading.svelte';

  interface Props {
    data: any[];
    config: TableConfig;
    loading?: boolean;
    error?: string | null;
    sort?: TableSort;
    filters?: TableFilter[];
    pagination?: TablePagination;
    selectedRows?: Set<string | number>;
    user?: User | null;
    emptyMessage?: string;
    rowKey?: string;
    onsort?: (sort: TableSort) => void;
    onfilter?: (filters: TableFilter[]) => void;
    onpaginate?: (pagination: Partial<TablePagination>) => void;
    onselect?: (selectedRows: Set<string | number>) => void;
    onaction?: (event: { action: string; row: any }) => void;
  }

  let {
    data = [],
    config,
    loading = false,
    error = null,
    sort = { column: '', direction: null },
    filters = [],
    pagination,
    selectedRows = new Set(),
    user = null,
    emptyMessage = 'No data available',
    rowKey = 'id',
    onsort,
    onfilter,
    onpaginate,
    onselect,
    onaction
  }: Props = $props();

  function handleSort(event: CustomEvent<TableSort>) {
    onsort?.(event.detail);
  }

  function handleSelectAll(event: CustomEvent<boolean>) {
    const newSelection = new Set<string | number>();
    
    if (event.detail) {
      // Select all visible rows
      data.forEach(row => {
        newSelection.add(row[rowKey]);
      });
    }
    
    onselect?.(newSelection);
  }

  function handleRowSelect(rowId: string | number, selected: boolean) {
    const newSelection = new Set(selectedRows);
    
    if (selected) {
      newSelection.add(rowId);
    } else {
      newSelection.delete(rowId);
    }
    
    onselect?.(newSelection);
  }

  function handlePaginate(event: CustomEvent<Partial<TablePagination>>) {
    onpaginate?.(event.detail);
  }

  function handleAction(action: TableAction, row: any) {
    if (action.disabled?.(row)) return;
    
    onaction?.({ action: action.label, row });
    action.onClick(row);
  }

  function getCellValue(row: any, column: TableColumn): string {
    const value = row[column.key];
    
    if (column.render) {
      return column.render(value, row);
    }
    
    if (value === null || value === undefined) {
      return '';
    }
    
    return String(value);
  }

  function getCellClass(column: TableColumn): string {
    const baseClass = 'px-6 py-4 whitespace-nowrap text-sm';
    const alignClass = column.align === 'center' ? 'text-center' : 
                      column.align === 'right' ? 'text-right' : 'text-left';
    const customClass = column.className || '';
    
    return `${baseClass} ${alignClass} ${customClass}`.trim();
  }

  function getVisibleActions(row: any): TableAction[] {
    if (!config.actions) return [];
    
    return config.actions.filter(action => {
      // Check visibility condition
      if (action.visible && !action.visible(row)) {
        return false;
      }
      
      // Check permissions
      if (action.permission && !hasPermission(user, action.permission as any)) {
        return false;
      }
      
      return true;
    });
  }

  function getActionButtonClass(action: TableAction): string {
    const baseClass = 'inline-flex items-center px-2.5 py-1.5 border text-xs font-medium rounded focus:outline-none focus:ring-2 focus:ring-offset-2';
    
    switch (action.variant) {
      case 'danger':
        return `${baseClass} border-red-300 text-red-700 bg-red-50 hover:bg-red-100 focus:ring-red-500`;
      case 'primary':
        return `${baseClass} border-blue-300 text-blue-700 bg-blue-50 hover:bg-blue-100 focus:ring-blue-500`;
      default:
        return `${baseClass} border-gray-300 text-gray-700 bg-white hover:bg-gray-50 focus:ring-blue-500`;
    }
  }

  let allSelected = $derived(data.length > 0 && data.every(row => selectedRows.has(row[rowKey])));
  let someSelected = $derived(data.some(row => selectedRows.has(row[rowKey])) && !allSelected);
  let tableClass = $derived([
    'min-w-full divide-y divide-gray-200',
    config.striped ? 'divide-y divide-gray-200' : '',
    config.compact ? 'text-sm' : ''
  ].filter(Boolean).join(' '));
</script>

<div class="flex flex-col">
  <div class="-my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
    <div class="py-2 align-middle inline-block min-w-full sm:px-6 lg:px-8">
      <div class="shadow overflow-hidden border-b border-gray-200 sm:rounded-lg">
        {#if loading}
          <div class="bg-white px-6 py-12">
            <Loading />
          </div>
        {:else if error}
          <div class="bg-white px-6 py-12 text-center">
            <div class="text-red-600 text-sm">{error}</div>
          </div>
        {:else if data.length === 0}
          <div class="bg-white px-6 py-12 text-center">
            <div class="text-gray-500 text-sm">{emptyMessage}</div>
          </div>
        {:else}
          <table class={tableClass}>
            <TableHeader
              columns={config.columns}
              {sort}
              selectable={config.selectable}
              {allSelected}
              {someSelected}
              onsort={(sortData) => handleSort({ detail: sortData })}
              onselectAll={(selected) => handleSelectAll({ detail: selected })}
            />
            
            <tbody class="bg-white divide-y divide-gray-200">
              {#each data as row, index}
                <tr class="{config.hover ? 'hover:bg-gray-50' : ''} {config.striped && index % 2 === 1 ? 'bg-gray-50' : ''}">
                  {#if config.selectable}
                    <td class="px-6 py-4 whitespace-nowrap">
                      <input
                        type="checkbox"
                        checked={selectedRows.has(row[rowKey])}
                        onchange={(e) => handleRowSelect(row[rowKey], e.currentTarget.checked)}
                        class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                        aria-label="Select row"
                      />
                    </td>
                  {/if}
                  
                  {#each config.columns as column}
                    <td class={getCellClass(column)}>
                      <div class="text-gray-900">
                        {getCellValue(row, column)}
                      </div>
                    </td>
                  {/each}
                  
                  <!-- Actions column -->
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    {#each getVisibleActions(row) as action}
                      <button
                        onclick={() => handleAction(action, row)}
                        disabled={action.disabled?.(row)}
                        class="{getActionButtonClass(action)} {action.disabled?.(row) ? 'opacity-50 cursor-not-allowed' : ''} mr-2 last:mr-0"
                        title={action.label}
                      >
                        {#if action.icon}
                          <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                            <path d={action.icon} />
                          </svg>
                        {/if}
                        {action.label}
                      </button>
                    {/each}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>
    </div>
  </div>
  
  {#if pagination && !loading && !error && data.length > 0}
    <TablePaginationComponent
      {pagination}
      onpaginate={(paginationData) => handlePaginate({ detail: paginationData })}
    />
  {/if}
</div>