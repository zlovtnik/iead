import { z } from 'zod';
import { requiredString, email, phone, nonNegativeNumber, optionalString } from './common.js';

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

export type Member = z.infer<typeof memberSchema>;
export type MemberCreate = z.infer<typeof memberCreateSchema>;
export type MemberUpdate = z.infer<typeof memberUpdateSchema>;
export type MemberSearch = z.infer<typeof memberSearchSchema>;