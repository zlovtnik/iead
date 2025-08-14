// Table utility functions for sorting, filtering, and pagination

import type { TableSort, TableFilter, TablePagination } from '../types/table.js';

/**
 * Sort data based on table sort configuration
 */
export function sortData<T>(data: T[], sort: TableSort): T[] {
  if (!sort.column || !sort.direction) {
    return data;
  }

  return [...data].sort((a, b) => {
    const aValue = getNestedValue(a, sort.column);
    const bValue = getNestedValue(b, sort.column);

    // Handle null/undefined values
    if (aValue == null && bValue == null) return 0;
    if (aValue == null) return sort.direction === 'asc' ? -1 : 1;
    if (bValue == null) return sort.direction === 'asc' ? 1 : -1;

    // Handle different data types
    if (typeof aValue === 'string' && typeof bValue === 'string') {
      const comparison = aValue.toLowerCase().localeCompare(bValue.toLowerCase());
      return sort.direction === 'asc' ? comparison : -comparison;
    }

    if (typeof aValue === 'number' && typeof bValue === 'number') {
      const comparison = aValue - bValue;
      return sort.direction === 'asc' ? comparison : -comparison;
    }

    if (aValue instanceof Date && bValue instanceof Date) {
      const comparison = aValue.getTime() - bValue.getTime();
      return sort.direction === 'asc' ? comparison : -comparison;
    }

    // Fallback to string comparison
    const aStr = String(aValue).toLowerCase();
    const bStr = String(bValue).toLowerCase();
    const comparison = aStr.localeCompare(bStr);
    return sort.direction === 'asc' ? comparison : -comparison;
  });
}

/**
 * Filter data based on table filter configuration
 */
export function filterData<T>(data: T[], filters: TableFilter[]): T[] {
  if (filters.length === 0) {
    return data;
  }

  return data.filter(item => {
    return filters.every(filter => {
      const value = getNestedValue(item, filter.column);
      const filterValue = filter.value.toLowerCase();
      const itemValue = String(value || '').toLowerCase();

      switch (filter.operator) {
        case 'equals':
          return itemValue === filterValue;
        case 'startsWith':
          return itemValue.startsWith(filterValue);
        case 'endsWith':
          return itemValue.endsWith(filterValue);
        case 'contains':
        default:
          return itemValue.includes(filterValue);
      }
    });
  });
}

/**
 * Paginate data based on pagination configuration
 */
export function paginateData<T>(data: T[], pagination: TablePagination): T[] {
  const startIndex = (pagination.page - 1) * pagination.pageSize;
  const endIndex = startIndex + pagination.pageSize;
  return data.slice(startIndex, endIndex);
}

/**
 * Calculate pagination info based on total items and page size
 */
export function calculatePagination(
  total: number,
  page: number,
  pageSize: number
): TablePagination {
  const totalPages = Math.ceil(total / pageSize);
  const validPage = Math.max(1, Math.min(page, totalPages));

  return {
    page: validPage,
    pageSize,
    total,
    totalPages
  };
}

/**
 * Get nested object value using dot notation
 */
function getNestedValue(obj: any, path: string): any {
  return path.split('.').reduce((current, key) => {
    return current?.[key];
  }, obj);
}

/**
 * Create default table sort
 */
export function createDefaultSort(column?: string, direction?: 'asc' | 'desc'): TableSort {
  return {
    column: column || '',
    direction: direction || null
  };
}

/**
 * Create default table pagination
 */
export function createDefaultPagination(
  page = 1,
  pageSize = 10,
  total = 0
): TablePagination {
  return calculatePagination(total, page, pageSize);
}

/**
 * Update table sort, handling toggle logic
 */
export function updateSort(currentSort: TableSort, column: string): TableSort {
  if (currentSort.column === column) {
    // Toggle through: asc -> desc -> null -> asc
    if (currentSort.direction === 'asc') {
      return { column, direction: 'desc' };
    } else if (currentSort.direction === 'desc') {
      return { column: '', direction: null };
    }
  }
  
  return { column, direction: 'asc' };
}

/**
 * Add or update a filter
 */
export function updateFilter(
  currentFilters: TableFilter[],
  column: string,
  value: string,
  operator: TableFilter['operator'] = 'contains'
): TableFilter[] {
  const existingIndex = currentFilters.findIndex(f => f.column === column);
  
  if (value.trim() === '') {
    // Remove filter if value is empty
    return currentFilters.filter(f => f.column !== column);
  }
  
  const newFilter: TableFilter = { column, value: value.trim(), operator };
  
  if (existingIndex >= 0) {
    // Update existing filter
    const updated = [...currentFilters];
    updated[existingIndex] = newFilter;
    return updated;
  } else {
    // Add new filter
    return [...currentFilters, newFilter];
  }
}

/**
 * Remove a filter
 */
export function removeFilter(currentFilters: TableFilter[], column: string): TableFilter[] {
  return currentFilters.filter(f => f.column !== column);
}

/**
 * Clear all filters
 */
export function clearFilters(): TableFilter[] {
  return [];
}

/**
 * Process data with sort, filter, and pagination
 */
export function processTableData<T>(
  data: T[],
  sort: TableSort,
  filters: TableFilter[],
  pagination?: TablePagination
): { data: T[]; total: number; pagination?: TablePagination } {
  // Apply filters first
  let processedData = filterData(data, filters);
  
  // Then apply sorting
  processedData = sortData(processedData, sort);
  
  const total = processedData.length;
  
  // Finally apply pagination if provided
  if (pagination) {
    const updatedPagination = calculatePagination(total, pagination.page, pagination.pageSize);
    processedData = paginateData(processedData, updatedPagination);
    
    return {
      data: processedData,
      total,
      pagination: updatedPagination
    };
  }
  
  return {
    data: processedData,
    total
  };
}

/**
 * Format common data types for display in tables
 */
export const tableFormatters = {
  date: (value: string | Date): string => {
    if (!value) return '';
    const date = value instanceof Date ? value : new Date(value);
    return date.toLocaleDateString();
  },
  
  datetime: (value: string | Date): string => {
    if (!value) return '';
    const date = value instanceof Date ? value : new Date(value);
    return date.toLocaleString();
  },
  
  currency: (value: number): string => {
    if (typeof value !== 'number') return '';
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(value);
  },
  
  percentage: (value: number): string => {
    if (typeof value !== 'number') return '';
    return `${(value * 100).toFixed(1)}%`;
  },
  
  boolean: (value: boolean): string => {
    return value ? 'Yes' : 'No';
  },
  
  truncate: (value: string, length = 50): string => {
    if (!value || typeof value !== 'string') return '';
    return value.length > length ? `${value.substring(0, length)}...` : value;
  }
};