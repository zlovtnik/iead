# Data Table Component System

A comprehensive table component system built for Svelte 5 with TypeScript, featuring sorting, filtering, pagination, and role-based actions.

## Components

### DataTable
The main table component that orchestrates all table functionality.

**Props:**
- `data: any[]` - Array of data to display
- `config: TableConfig` - Table configuration object
- `loading?: boolean` - Loading state
- `error?: string | null` - Error message to display
- `sort?: TableSort` - Current sort configuration
- `filters?: TableFilter[]` - Current filters
- `pagination?: TablePagination` - Pagination configuration
- `selectedRows?: Set<string | number>` - Selected row IDs
- `user?: User | null` - Current user for permission checks
- `emptyMessage?: string` - Message when no data
- `rowKey?: string` - Key to use for row identification (default: 'id')

**Events:**
- `onsort: (sort: TableSort) => void` - Sort change event
- `onfilter: (filters: TableFilter[]) => void` - Filter change event
- `onpaginate: (pagination: Partial<TablePagination>) => void` - Pagination change event
- `onselect: (selectedRows: Set<string | number>) => void` - Selection change event
- `onaction: (event: { action: string; row: any }) => void` - Action button click event

### TableHeader
Header component with sorting indicators and column configuration.

**Props:**
- `columns: TableColumn[]` - Column definitions
- `sort?: TableSort` - Current sort state
- `selectable?: boolean` - Show selection checkbox
- `allSelected?: boolean` - All rows selected state
- `someSelected?: boolean` - Some rows selected state

**Events:**
- `onsort: (sort: TableSort) => void` - Sort change event
- `onselectAll: (selected: boolean) => void` - Select all event

### TablePagination
Pagination component with page size options and navigation.

**Props:**
- `pagination: TablePagination` - Pagination state
- `pageSizeOptions?: number[]` - Available page sizes (default: [10, 25, 50, 100])
- `showPageSizeSelector?: boolean` - Show page size dropdown (default: true)
- `showPageInfo?: boolean` - Show pagination info (default: true)
- `maxVisiblePages?: number` - Max page buttons to show (default: 5)

**Events:**
- `onpaginate: (pagination: Partial<TablePagination>) => void` - Pagination change event

## Types

### TableColumn
```typescript
interface TableColumn<T = any> {
  key: string;                    // Data property key
  label: string;                  // Column header text
  sortable?: boolean;             // Enable sorting
  filterable?: boolean;           // Enable filtering
  width?: string;                 // Column width (CSS)
  align?: 'left' | 'center' | 'right'; // Text alignment
  render?: (value: any, row: T) => string; // Custom renderer
  className?: string;             // Additional CSS classes
}
```

### TableAction
```typescript
interface TableAction<T = any> {
  label: string;                  // Button text
  icon?: string;                  // SVG path for icon
  variant?: 'primary' | 'secondary' | 'danger'; // Button style
  permission?: string;            // Required permission
  onClick: (row: T) => void;      // Click handler
  disabled?: (row: T) => boolean; // Disable condition
  visible?: (row: T) => boolean;  // Visibility condition
}
```

### TableConfig
```typescript
interface TableConfig<T = any> {
  columns: TableColumn<T>[];      // Column definitions
  actions?: TableAction<T>[];     // Row actions
  sortable?: boolean;             // Enable sorting
  filterable?: boolean;           // Enable filtering
  paginated?: boolean;            // Enable pagination
  selectable?: boolean;           // Enable row selection
  striped?: boolean;              // Striped rows
  hover?: boolean;                // Hover effects
  compact?: boolean;              // Compact layout
}
```

## Usage Examples

### Basic Table
```svelte
<script>
  import { DataTable } from '$lib/components/ui';
  
  const data = [
    { id: 1, name: 'John Doe', email: 'john@example.com' },
    { id: 2, name: 'Jane Smith', email: 'jane@example.com' }
  ];
  
  const config = {
    columns: [
      { key: 'name', label: 'Name', sortable: true },
      { key: 'email', label: 'Email', sortable: true }
    ]
  };
</script>

<DataTable {data} {config} />
```

### Table with Actions and Permissions
```svelte
<script>
  import { DataTable } from '$lib/components/ui';
  
  const config = {
    columns: [
      { key: 'name', label: 'Name', sortable: true },
      { key: 'email', label: 'Email', sortable: true },
      { 
        key: 'salary', 
        label: 'Salary', 
        sortable: true, 
        align: 'right',
        render: (value) => new Intl.NumberFormat('en-US', {
          style: 'currency',
          currency: 'USD'
        }).format(value)
      }
    ],
    actions: [
      {
        label: 'Edit',
        variant: 'primary',
        permission: 'member:write',
        onClick: (row) => editMember(row)
      },
      {
        label: 'Delete',
        variant: 'danger',
        permission: 'member:delete',
        onClick: (row) => deleteMember(row),
        disabled: (row) => !row.is_active
      }
    ],
    sortable: true,
    paginated: true,
    selectable: true,
    striped: true,
    hover: true
  };
  
  function handleSort(sort) {
    // Update sort state
  }
  
  function handlePaginate(pagination) {
    // Update pagination state
  }
</script>

<DataTable 
  {data} 
  {config} 
  {user}
  onsort={handleSort}
  onpaginate={handlePaginate}
/>
```

### Server-Side Processing
```svelte
<script>
  import { DataTable } from '$lib/components/ui';
  import { processTableData } from '$lib/utils/table';
  
  let sort = { column: '', direction: null };
  let filters = [];
  let pagination = { page: 1, pageSize: 10, total: 0, totalPages: 0 };
  let loading = false;
  
  // For client-side processing
  $: processedData = processTableData(rawData, sort, filters, pagination);
  
  // For server-side processing
  async function fetchData() {
    loading = true;
    try {
      const response = await api.getMembers({
        sort,
        filters,
        page: pagination.page,
        pageSize: pagination.pageSize
      });
      
      data = response.data;
      pagination = response.pagination;
    } finally {
      loading = false;
    }
  }
  
  function handleSort(newSort) {
    sort = newSort;
    fetchData(); // For server-side
  }
</script>

<DataTable 
  data={processedData.data}
  {config}
  {sort}
  {filters}
  pagination={processedData.pagination}
  {loading}
  onsort={handleSort}
/>
```

## Utility Functions

The `table.ts` utility file provides helper functions for data processing:

- `sortData(data, sort)` - Sort data array
- `filterData(data, filters)` - Filter data array
- `paginateData(data, pagination)` - Paginate data array
- `processTableData(data, sort, filters, pagination)` - Process all operations
- `calculatePagination(total, page, pageSize)` - Calculate pagination info
- `updateSort(currentSort, column)` - Update sort with toggle logic
- `updateFilter(filters, column, value, operator)` - Add/update filter
- `tableFormatters` - Common data formatters (currency, date, etc.)

## Styling

The components use Tailwind CSS classes and follow the design system:

- **Colors**: Gray-based with blue accents for interactive elements
- **Spacing**: Consistent padding and margins using Tailwind scale
- **Typography**: Clear hierarchy with proper font weights
- **States**: Hover, focus, and disabled states for accessibility
- **Responsive**: Mobile-first design with responsive breakpoints

## Accessibility

The table components include comprehensive accessibility features:

- **ARIA Labels**: Proper labeling for screen readers
- **Keyboard Navigation**: Full keyboard support for all interactions
- **Sort Indicators**: ARIA sort attributes for column headers
- **Focus Management**: Visible focus indicators and logical tab order
- **Screen Reader Support**: Descriptive text for complex interactions

## Performance

The table system is optimized for performance:

- **Virtual Scrolling**: Can be added for large datasets
- **Memoization**: Derived values prevent unnecessary recalculations
- **Efficient Updates**: Minimal DOM updates using Svelte's reactivity
- **Code Splitting**: Components can be lazy-loaded
- **Memory Management**: Proper cleanup of event listeners and subscriptions