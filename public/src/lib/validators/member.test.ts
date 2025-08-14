import { describe, it, expect } from 'vitest';
import {
  memberSchema,
  memberCreateSchema,
  memberUpdateSchema,
  memberSearchSchema,
  memberFiltersSchema,
  memberExportSchema,
  memberQuickSearchSchema,
  memberBulkDeleteSchema
} from './member.js';

describe('Member Validation Schemas', () => {
  describe('memberSchema', () => {
    it('should validate a valid member', () => {
      const validMember = {
        name: 'John Doe',
        email: 'john@example.com',
        phone: '+1234567890',
        salary: 50000
      };

      const result = memberSchema.safeParse(validMember);
      expect(result.success).toBe(true);
    });

    it('should require name and email', () => {
      const invalidMember = {
        phone: '+1234567890'
      };

      const result = memberSchema.safeParse(invalidMember);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues).toHaveLength(2); // name and email required
      }
    });

    it('should validate email format', () => {
      const invalidMember = {
        name: 'John Doe',
        email: 'invalid-email'
      };

      const result = memberSchema.safeParse(invalidMember);
      expect(result.success).toBe(false);
    });

    it('should allow optional fields', () => {
      const minimalMember = {
        name: 'John Doe',
        email: 'john@example.com'
      };

      const result = memberSchema.safeParse(minimalMember);
      expect(result.success).toBe(true);
    });
  });

  describe('memberUpdateSchema', () => {
    it('should require ID for updates', () => {
      const updateData = {
        name: 'Jane Doe'
      };

      const result = memberUpdateSchema.safeParse(updateData);
      expect(result.success).toBe(false);
    });

    it('should validate partial updates with ID', () => {
      const updateData = {
        id: 1,
        name: 'Jane Doe'
      };

      const result = memberUpdateSchema.safeParse(updateData);
      expect(result.success).toBe(true);
    });
  });

  describe('memberSearchSchema', () => {
    it('should use default values', () => {
      const searchData = {};

      const result = memberSearchSchema.parse(searchData);
      expect(result.sortBy).toBe('name');
      expect(result.sortOrder).toBe('asc');
      expect(result.page).toBe(1);
      expect(result.limit).toBe(20);
    });

    it('should validate sort options', () => {
      const searchData = {
        sortBy: 'invalid' as any
      };

      const result = memberSearchSchema.safeParse(searchData);
      expect(result.success).toBe(false);
    });
  });

  describe('memberFiltersSchema', () => {
    it('should validate salary range', () => {
      const validFilters = {
        minSalary: 30000,
        maxSalary: 60000
      };

      const result = memberFiltersSchema.safeParse(validFilters);
      expect(result.success).toBe(true);
    });

    it('should reject invalid salary range', () => {
      const invalidFilters = {
        minSalary: 60000,
        maxSalary: 30000
      };

      const result = memberFiltersSchema.safeParse(invalidFilters);
      expect(result.success).toBe(false);
    });

    it('should validate date range', () => {
      const validFilters = {
        createdAfter: '2024-01-01',
        createdBefore: '2024-12-31'
      };

      const result = memberFiltersSchema.safeParse(validFilters);
      expect(result.success).toBe(true);
    });

    it('should reject invalid date range', () => {
      const invalidFilters = {
        createdAfter: '2024-12-31',
        createdBefore: '2024-01-01'
      };

      const result = memberFiltersSchema.safeParse(invalidFilters);
      expect(result.success).toBe(false);
    });
  });

  describe('memberQuickSearchSchema', () => {
    it('should require query', () => {
      const searchData = {};

      const result = memberQuickSearchSchema.safeParse(searchData);
      expect(result.success).toBe(false);
    });

    it('should validate with query', () => {
      const searchData = {
        query: 'John'
      };

      const result = memberQuickSearchSchema.safeParse(searchData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.limit).toBe(10); // default
      }
    });
  });

  describe('memberBulkDeleteSchema', () => {
    it('should require at least one member ID', () => {
      const bulkData = {
        memberIds: []
      };

      const result = memberBulkDeleteSchema.safeParse(bulkData);
      expect(result.success).toBe(false);
    });

    it('should validate with member IDs', () => {
      const bulkData = {
        memberIds: [1, 2, 3]
      };

      const result = memberBulkDeleteSchema.safeParse(bulkData);
      expect(result.success).toBe(true);
    });
  });

  describe('memberExportSchema', () => {
    it('should use default format', () => {
      const exportData = {};

      const result = memberExportSchema.parse(exportData);
      expect(result.format).toBe('csv');
    });

    it('should validate format options', () => {
      const exportData = {
        format: 'xlsx' as const
      };

      const result = memberExportSchema.safeParse(exportData);
      expect(result.success).toBe(true);
    });
  });
});