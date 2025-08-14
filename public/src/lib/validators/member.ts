import { z } from 'zod';
import { requiredString, email, phone, nonNegativeNumber, optionalString, dateString, positiveNumber } from './common.js';

/**
 * Member-related validation schemas
 */

export const memberSchema = z.object({
  name: requiredString('Member name is required'),
  email: email,
  phone: phone,
  salary: nonNegativeNumber.optional(),
});

export const memberCreateSchema = memberSchema;

export const memberUpdateSchema = memberSchema.partial().extend({
  id: z.number().int().positive('Invalid member ID'),
});

export const memberSearchSchema = z.object({
  query: optionalString,
  sortBy: z.enum(['name', 'email', 'created_at']).default('name'),
  sortOrder: z.enum(['asc', 'desc']).default('asc'),
  page: z.number().int().positive().default(1),
  limit: z.number().int().positive().max(100).default(20),
});

export const memberFiltersSchema = z.object({
  hasEmail: z.boolean().optional(),
  hasPhone: z.boolean().optional(),
  hasSalary: z.boolean().optional(),
  minSalary: nonNegativeNumber.optional(),
  maxSalary: nonNegativeNumber.optional(),
  createdAfter: dateString.optional(),
  createdBefore: dateString.optional(),
}).refine(
  (data) => {
    // If both min and max salary are provided, min should be less than max
    if (data.minSalary !== undefined && data.maxSalary !== undefined) {
      return data.minSalary <= data.maxSalary;
    }
    return true;
  },
  {
    message: 'Minimum salary must be less than or equal to maximum salary',
    path: ['minSalary']
  }
).refine(
  (data) => {
    // If both dates are provided, createdAfter should be before createdBefore
    if (data.createdAfter && data.createdBefore) {
      return new Date(data.createdAfter) <= new Date(data.createdBefore);
    }
    return true;
  },
  {
    message: 'Start date must be before or equal to end date',
    path: ['createdAfter']
  }
);

export const memberExportSchema = z.object({
  format: z.enum(['csv', 'xlsx']).default('csv'),
  filters: memberFiltersSchema.optional(),
});

export const memberStatsSchema = z.object({
  id: z.number().int().positive('Invalid member ID'),
});

export const memberBirthdaysSchema = z.object({
  days: z.number().int().positive().max(365).default(30),
});

// Quick search schema for autocomplete/typeahead
export const memberQuickSearchSchema = z.object({
  query: requiredString('Search query is required'),
  limit: z.number().int().positive().max(50).default(10),
});

// Bulk operations schema
export const memberBulkDeleteSchema = z.object({
  memberIds: z.array(z.number().int().positive()).min(1, 'At least one member must be selected'),
});

export const memberBulkUpdateSchema = z.object({
  memberIds: z.array(z.number().int().positive()).min(1, 'At least one member must be selected'),
  updates: memberSchema.partial().refine(
    (data) => Object.keys(data).length > 0,
    'At least one field must be updated'
  ),
});

export type Member = z.infer<typeof memberSchema>;
export type MemberCreate = z.infer<typeof memberCreateSchema>;
export type MemberUpdate = z.infer<typeof memberUpdateSchema>;
export type MemberSearch = z.infer<typeof memberSearchSchema>;
export type MemberFilters = z.infer<typeof memberFiltersSchema>;
export type MemberExport = z.infer<typeof memberExportSchema>;
export type MemberStats = z.infer<typeof memberStatsSchema>;
export type MemberBirthdays = z.infer<typeof memberBirthdaysSchema>;
export type MemberQuickSearch = z.infer<typeof memberQuickSearchSchema>;
export type MemberBulkDelete = z.infer<typeof memberBulkDeleteSchema>;
export type MemberBulkUpdate = z.infer<typeof memberBulkUpdateSchema>;