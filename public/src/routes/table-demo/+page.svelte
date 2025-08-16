<script lang="ts">
  import { DataTable } from '$lib/components/ui';
  import type { TableConfig, TableSort, TableFilter, TablePagination } from '$lib/types/table';
  import { processTableData, tableFormatters } from '$lib/utils/table';
  import { onMount } from 'svelte';

  // Sample data for demonstration
  interface SampleMember {
    id: number;
    name: string;
    email: string;
    phone: string;
    salary: number;
    created_at: string;
    is_active: boolean;
  }

  const sampleData: SampleMember[] = [
    {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      phone: '(555) 123-4567',
      salary: 50000,
      created_at: '2024-01-15T10:30:00Z',
      is_active: true
    },
    {
      id: 2,
      name: 'Jane Smith',
      email: 'jane@example.com',
      phone: '(555) 987-6543',
      salary: 65000,
      created_at: '2024-02-20T14:15:00Z',
      is_active: true
    },
    {
      id: 3,
      name: 'Bob Johnson',
      email: 'bob@example.com',
      phone: '(555) 456-7890',
      salary: 45000,
      created_at: '2024-03-10T09:45:00Z',
      is_active: false
    },
    {
      id: 4,
      name: 'Alice Brown',
      email: 'alice@example.com',
      phone: '(555) 321-0987',
      salary: 70000,
      created_at: '2024-01-25T16:20:00Z',
      is_active: true
    },
    {
      id: 5,
      name: 'Charlie Wilson',
      email: 'charlie@example.com',
      phone: '(555) 654-3210',
      salary: 55000,
      created_at: '2024-02-05T11:10:00Z',
      is_active: true
    }
  ];

  // Table configuration
  const tableConfig: TableConfig<SampleMember> = {
    columns: [
      {
        key: 'name',
        label: 'Name',
        sortable: true,
        filterable: true
      },
      {
        key: 'email',
        label: 'Email',
        sortable: true,
        filterable: true
      },
      {
        key: 'phone',
        label: 'Phone',
        sortable: false,
        filterable: false
      },
      {
        key: 'salary',
        label: 'Salary',
        sortable: true,
        filterable: false,
        align: 'right',
        render: (value) => tableFormatters.currency(value)
      },
      {
        key: 'created_at',
        label: 'Created',
        sortable: true,
        filterable: false,
        render: (value) => tableFormatters.date(value)
      },
      {
        key: 'is_active',
        label: 'Status',
        sortable: true,
        filterable: false,
        align: 'center',
        render: (value) => value ? 'Active' : 'Inactive'
      }
    ],
    actions: [
      {
        label: 'Edit',
        variant: 'primary',
        permission: 'member:write',
        onClick: (row) => {
          alert(`Edit member: ${row.name}`);
        }
      },
      {
        label: 'Delete',
        variant: 'danger',
        permission: 'member:delete',
        onClick: (row) => {
          if (confirm(`Delete member: ${row.name}?`)) {
            alert(`Deleted member: ${row.name}`);
          }
        },
        disabled: (row) => !row.is_active
      }
    ],
    sortable: true,
    filterable: true,
    paginated: true,
    selectable: true,
    striped: true,
    hover: true
  };

  // Table state
  let sort: TableSort = { column: '', direction: null };
  let filters: TableFilter[] = [];
  let pagination: TablePagination = {
    page: 1,
    pageSize: 3,
    total: 0,
    totalPages: 0
  };
  let selectedRows = new Set<string | number>();
  let loading = false;
  let error: string | null = null;

  // Processed data
  let displayData: SampleMember[] = [];

  // Mock user for permission testing
  const mockUser = {
    id: 1,
    username: 'admin',
    email: 'admin@example.com',
    role: 'Admin' as const,
    member_id: null,
    is_active: true,
    failed_login_attempts: 0,
    last_login: '2024-01-01T00:00:00Z',
    password_reset_required: false,
    created_at: '2024-01-01T00:00:00Z'
  };

  function updateDisplayData() {
    const result = processTableData(sampleData, sort, filters, pagination);
    displayData = result.data;
    pagination = result.pagination!;
  }

  function handleSort(event: CustomEvent<TableSort>) {
    sort = event.detail;
    pagination.page = 1; // Reset to first page when sorting
    updateDisplayData();
  }

  function handleFilter(event: CustomEvent<TableFilter[]>) {
    filters = event.detail;
    pagination.page = 1; // Reset to first page when filtering
    updateDisplayData();
  }

  function handlePaginate(event: CustomEvent<Partial<TablePagination>>) {
    pagination = { ...pagination, ...event.detail };
    updateDisplayData();
  }

  function handleSelect(event: CustomEvent<Set<string | number>>) {
    selectedRows = event.detail;
  }

  function handleAction(event: CustomEvent<{ action: string; row: SampleMember }>) {
    console.log('Action triggered:', event.detail);
  }

  // Initialize data on mount
  onMount(() => {
    pagination.total = sampleData.length;
    pagination.totalPages = Math.ceil(sampleData.length / pagination.pageSize);
    updateDisplayData();
  });
</script>

<svelte:head>
  <title>Table Demo - Church Management System</title>
</svelte:head>

<div class="container mx-auto px-4 py-8">
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-gray-900 mb-2">Data Table Demo</h1>
    <p class="text-gray-600">
      Demonstration of the DataTable component with sorting, filtering, pagination, and actions.
    </p>
  </div>

  <div class="bg-white shadow rounded-lg">
    <div class="px-6 py-4 border-b border-gray-200">
      <h2 class="text-lg font-medium text-gray-900">Members</h2>
      <p class="text-sm text-gray-500 mt-1">
        Sample member data with various table features enabled.
      </p>
    </div>

    <DataTable
      data={displayData}
      config={tableConfig}
      {sort}
      {filters}
      {pagination}
      {selectedRows}
      {loading}
      {error}
      user={mockUser}
      emptyMessage="No members found"
      rowKey="id"
      onsort={(sortData) => handleSort({ detail: sortData })}
      onfilter={(filterData) => handleFilter({ detail: filterData })}
      onpaginate={(paginationData) => handlePaginate({ detail: paginationData })}
      onselect={(selectedData) => handleSelect({ detail: selectedData })}
      onaction={(actionData) => handleAction({ detail: actionData })}
    />
  </div>

  <div class="mt-8 bg-gray-50 rounded-lg p-6">
    <h3 class="text-lg font-medium text-gray-900 mb-4">Table State</h3>
    
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <h4 class="font-medium text-gray-700 mb-2">Sort</h4>
        <pre class="bg-white p-3 rounded border text-sm">{JSON.stringify(sort, null, 2)}</pre>
      </div>
      
      <div>
        <h4 class="font-medium text-gray-700 mb-2">Filters</h4>
        <pre class="bg-white p-3 rounded border text-sm">{JSON.stringify(filters, null, 2)}</pre>
      </div>
      
      <div>
        <h4 class="font-medium text-gray-700 mb-2">Pagination</h4>
        <pre class="bg-white p-3 rounded border text-sm">{JSON.stringify(pagination, null, 2)}</pre>
      </div>
      
      <div>
        <h4 class="font-medium text-gray-700 mb-2">Selected Rows</h4>
        <pre class="bg-white p-3 rounded border text-sm">{JSON.stringify(Array.from(selectedRows), null, 2)}</pre>
      </div>
    </div>
  </div>
</div>