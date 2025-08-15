import { describe, it, expect } from 'vitest';
import {
  sortData,
  filterData,
  paginateData,
  calculatePagination,
  updateSort,
  updateFilter,
  processTableData,
  tableFormatters
} from './table';
import type { TableSort, TableFilter } from '../types/table';

describe('Table Utilities', () => {
  const sampleData = [
    { id: 1, name: 'Alice', age: 30, active: true, created: '2024-01-01' },
    { id: 2, name: 'Bob', age: 25, active: false, created: '2024-02-01' },
    { id: 3, name: 'Charlie', age: 35, active: true, created: '2024-01-15' },
    { id: 4, name: 'Diana', age: 28, active: true, created: '2024-03-01' }
  ];

  describe('sortData', () => {
    it('should sort data in ascending order', () => {
      const sort: TableSort = { column: 'name', direction: 'asc' };
      const result = sortData(sampleData, sort);
      
      expect(result[0].name).toBe('Alice');
      expect(result[1].name).toBe('Bob');
      expect(result[2].name).toBe('Charlie');
      expect(result[3].name).toBe('Diana');
    });

    it('should sort data in descending order', () => {
      const sort: TableSort = { column: 'age', direction: 'desc' };
      const result = sortData(sampleData, sort);
      
      expect(result[0].age).toBe(35);
      expect(result[1].age).toBe(30);
      expect(result[2].age).toBe(28);
      expect(result[3].age).toBe(25);
    });

    it('should return original data when no sort is applied', () => {
      const sort: TableSort = { column: '', direction: null };
      const result = sortData(sampleData, sort);
      
      expect(result).toEqual(sampleData);
    });

    it('should handle null values correctly', () => {
      const dataWithNulls = [
        { id: 1, name: 'Alice', value: 10 },
        { id: 2, name: 'Bob', value: null },
        { id: 3, name: 'Charlie', value: 5 }
      ];
      
      const sort: TableSort = { column: 'value', direction: 'asc' };
      const result = sortData(dataWithNulls, sort);
      
      expect(result[0].value).toBe(null);
      expect(result[1].value).toBe(5);
      expect(result[2].value).toBe(10);
    });
  });

  describe('filterData', () => {
    it('should filter data with contains operator', () => {
      const filters: TableFilter[] = [
        { column: 'name', value: 'a', operator: 'contains' }
      ];
      const result = filterData(sampleData, filters);
      
      expect(result).toHaveLength(3); // Alice, Charlie, Diana
      expect(result.map(r => r.name)).toEqual(['Alice', 'Charlie', 'Diana']);
    });

    it('should filter data with equals operator', () => {
      const filters: TableFilter[] = [
        { column: 'active', value: 'true', operator: 'equals' }
      ];
      const result = filterData(sampleData, filters);
      
      expect(result).toHaveLength(3);
      expect(result.every(r => r.active)).toBe(true);
    });

    it('should filter data with startsWith operator', () => {
      const filters: TableFilter[] = [
        { column: 'name', value: 'C', operator: 'startsWith' }
      ];
      const result = filterData(sampleData, filters);
      
      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('Charlie');
    });

    it('should apply multiple filters', () => {
      const filters: TableFilter[] = [
        { column: 'active', value: 'true', operator: 'equals' },
        { column: 'age', value: '30', operator: 'contains' }
      ];
      const result = filterData(sampleData, filters);
      
      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('Alice');
    });

    it('should return all data when no filters applied', () => {
      const result = filterData(sampleData, []);
      expect(result).toEqual(sampleData);
    });
  });

  describe('paginateData', () => {
    it('should return correct page of data', () => {
      const pagination = { page: 2, pageSize: 2, total: 4, totalPages: 2 };
      const result = paginateData(sampleData, pagination);
      
      expect(result).toHaveLength(2);
      expect(result[0].name).toBe('Charlie');
      expect(result[1].name).toBe('Diana');
    });

    it('should handle last page with fewer items', () => {
      const pagination = { page: 2, pageSize: 3, total: 4, totalPages: 2 };
      const result = paginateData(sampleData, pagination);
      
      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('Diana');
    });
  });

  describe('calculatePagination', () => {
    it('should calculate pagination correctly', () => {
      const result = calculatePagination(25, 3, 10);
      
      expect(result).toEqual({
        page: 3,
        pageSize: 10,
        total: 25,
        totalPages: 3
      });
    });

    it('should handle page number out of bounds', () => {
      const result = calculatePagination(25, 10, 10);
      
      expect(result.page).toBe(3); // Should be clamped to max page
    });

    it('should handle zero total', () => {
      const result = calculatePagination(0, 1, 10);
      
      expect(result).toEqual({
        page: 1,
        pageSize: 10,
        total: 0,
        totalPages: 0
      });
    });
  });

  describe('updateSort', () => {
    it('should create new sort for different column', () => {
      const currentSort: TableSort = { column: 'name', direction: 'asc' };
      const result = updateSort(currentSort, 'age');
      
      expect(result).toEqual({ column: 'age', direction: 'asc' });
    });

    it('should toggle sort direction for same column', () => {
      const currentSort: TableSort = { column: 'name', direction: 'asc' };
      const result = updateSort(currentSort, 'name');
      
      expect(result).toEqual({ column: 'name', direction: 'desc' });
    });

    it('should clear sort after desc', () => {
      const currentSort: TableSort = { column: 'name', direction: 'desc' };
      const result = updateSort(currentSort, 'name');
      
      expect(result).toEqual({ column: '', direction: null });
    });
  });

  describe('updateFilter', () => {
    it('should add new filter', () => {
      const result = updateFilter([], 'name', 'Alice');
      
      expect(result).toEqual([
        { column: 'name', value: 'Alice', operator: 'contains' }
      ]);
    });

    it('should update existing filter', () => {
      const currentFilters: TableFilter[] = [
        { column: 'name', value: 'Alice', operator: 'contains' }
      ];
      const result = updateFilter(currentFilters, 'name', 'Bob');
      
      expect(result).toEqual([
        { column: 'name', value: 'Bob', operator: 'contains' }
      ]);
    });

    it('should remove filter when value is empty', () => {
      const currentFilters: TableFilter[] = [
        { column: 'name', value: 'Alice', operator: 'contains' }
      ];
      const result = updateFilter(currentFilters, 'name', '');
      
      expect(result).toEqual([]);
    });
  });

  describe('processTableData', () => {
    it('should process data with all operations', () => {
      const sort: TableSort = { column: 'name', direction: 'asc' };
      const filters: TableFilter[] = [
        { column: 'active', value: 'true', operator: 'equals' }
      ];
      const pagination = { page: 1, pageSize: 2, total: 0, totalPages: 0 };
      
      const result = processTableData(sampleData, sort, filters, pagination);
      
      expect(result.data).toHaveLength(2);
      expect(result.data[0].name).toBe('Alice');
      expect(result.data[1].name).toBe('Charlie');
      expect(result.total).toBe(3); // 3 active users
      expect(result.pagination?.totalPages).toBe(2);
    });
  });

  describe('tableFormatters', () => {
    it('should format currency correctly', () => {
      expect(tableFormatters.currency(1234.56)).toBe('$1,234.56');
      expect(tableFormatters.currency(0)).toBe('$0.00');
    });

    it('should format percentage correctly', () => {
      expect(tableFormatters.percentage(0.1234)).toBe('12.3%');
      expect(tableFormatters.percentage(1)).toBe('100.0%');
    });

    it('should format boolean correctly', () => {
      expect(tableFormatters.boolean(true)).toBe('Yes');
      expect(tableFormatters.boolean(false)).toBe('No');
    });

    it('should truncate text correctly', () => {
      const longText = 'This is a very long text that should be truncated';
      expect(tableFormatters.truncate(longText, 20)).toBe('This is a very long ...');
      expect(tableFormatters.truncate('Short', 20)).toBe('Short');
    });

    it('should format dates correctly', () => {
      const date = new Date('2024-01-15T10:30:00Z');
      const formatted = tableFormatters.date(date);
      expect(formatted).toMatch(/\d{1,2}\/\d{1,2}\/\d{4}/); // MM/DD/YYYY or similar
    });
  });
});