// Table component types and interfaces

export type SortDirection = 'asc' | 'desc' | null;

export interface TableColumn<T = any> {
  key: string;
  label: string;
  sortable?: boolean;
  filterable?: boolean;
  width?: string;
  align?: 'left' | 'center' | 'right';
  render?: (value: any, row: T) => string;
  className?: string;
}

export interface TableSort {
  column: string;
  direction: SortDirection;
}

export interface TableFilter {
  column: string;
  value: string;
  operator?: 'contains' | 'equals' | 'startsWith' | 'endsWith';
}

export interface TablePagination {
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

export interface TableAction<T = any> {
  label: string;
  icon?: string;
  variant?: 'primary' | 'secondary' | 'danger';
  permission?: string;
  onClick: (row: T) => void;
  disabled?: (row: T) => boolean;
  visible?: (row: T) => boolean;
}

export interface TableConfig<T = any> {
  columns: TableColumn<T>[];
  actions?: TableAction<T>[];
  sortable?: boolean;
  filterable?: boolean;
  paginated?: boolean;
  selectable?: boolean;
  striped?: boolean;
  hover?: boolean;
  compact?: boolean;
}

export interface TableState {
  sort: TableSort;
  filters: TableFilter[];
  pagination: TablePagination;
  selectedRows: Set<string | number>;
  loading: boolean;
  error: string | null;
}

export interface TableEvents<T = any> {
  sort: (sort: TableSort) => void;
  filter: (filters: TableFilter[]) => void;
  paginate: (pagination: Partial<TablePagination>) => void;
  select: (selectedRows: Set<string | number>) => void;
  action: (action: string, row: T) => void;
}