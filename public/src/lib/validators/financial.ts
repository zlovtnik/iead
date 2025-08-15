import { z } from 'zod';

// Base validation rules
const positiveAmount = z.number().positive('Amount must be greater than 0').max(1000000, 'Amount is too large');
const validDate = z.string().refine((date) => !isNaN(Date.parse(date)), 'Invalid date format');
const monthNumber = z.number().int().min(1, 'Month must be between 1 and 12').max(12, 'Month must be between 1 and 12');
const yearNumber = z.number().int().min(1900, 'Year must be valid').max(2100, 'Year must be valid');

// Donation validation schemas
export const donationCreateSchema = z.object({
  member_id: z.number().int().positive('Member ID is required'),
  amount: positiveAmount,
  donation_date: validDate,
  category: z.string().min(1, 'Category is required').max(100, 'Category is too long').optional(),
  notes: z.string().max(500, 'Notes are too long').optional()
});

export const donationUpdateSchema = donationCreateSchema.partial().extend({
  id: z.number().int().positive('Donation ID is required')
});

export const donationSearchSchema = z.object({
  query: z.string().optional(),
  member_id: z.number().int().positive().optional(),
  category: z.string().optional(),
  startDate: validDate.optional(),
  endDate: validDate.optional(),
  minAmount: z.number().positive().optional(),
  maxAmount: z.number().positive().optional(),
  sortBy: z.enum(['donation_date', 'amount', 'member_name', 'category', 'created_at']).optional(),
  sortOrder: z.enum(['asc', 'desc']).optional(),
  page: z.number().int().positive().optional(),
  limit: z.number().int().positive().max(100).optional()
}).refine((data) => {
  if (data.startDate && data.endDate) {
    return new Date(data.startDate) <= new Date(data.endDate);
  }
  return true;
}, 'Start date must be before or equal to end date').refine((data) => {
  if (data.minAmount && data.maxAmount) {
    return data.minAmount <= data.maxAmount;
  }
  return true;
}, 'Minimum amount must be less than or equal to maximum amount');

// Tithe validation schemas
export const titheCreateSchema = z.object({
  member_id: z.number().int().positive('Member ID is required'),
  amount: positiveAmount,
  month: monthNumber,
  year: yearNumber,
  is_paid: z.boolean().optional().default(false),
  paid_date: validDate.optional()
}).refine((data) => {
  // If is_paid is true, paid_date should be provided
  if (data.is_paid && !data.paid_date) {
    return false;
  }
  return true;
}, 'Paid date is required when tithe is marked as paid');

export const titheUpdateSchema = z.object({
  id: z.number().int().positive('Tithe ID is required'),
  amount: positiveAmount.optional(),
  month: monthNumber.optional(),
  year: yearNumber.optional(),
  is_paid: z.boolean().optional(),
  paid_date: validDate.optional()
}).refine((data) => {
  // If is_paid is true, paid_date should be provided
  if (data.is_paid && !data.paid_date) {
    return false;
  }
  return true;
}, 'Paid date is required when tithe is marked as paid');

export const titheSearchSchema = z.object({
  query: z.string().optional(),
  member_id: z.number().int().positive().optional(),
  month: monthNumber.optional(),
  year: yearNumber.optional(),
  is_paid: z.boolean().optional(),
  startDate: validDate.optional(),
  endDate: validDate.optional(),
  minAmount: z.number().positive().optional(),
  maxAmount: z.number().positive().optional(),
  sortBy: z.enum(['month', 'year', 'amount', 'member_name', 'paid_date', 'created_at']).optional(),
  sortOrder: z.enum(['asc', 'desc']).optional(),
  page: z.number().int().positive().optional(),
  limit: z.number().int().positive().max(100).optional()
}).refine((data) => {
  if (data.startDate && data.endDate) {
    return new Date(data.startDate) <= new Date(data.endDate);
  }
  return true;
}, 'Start date must be before or equal to end date').refine((data) => {
  if (data.minAmount && data.maxAmount) {
    return data.minAmount <= data.maxAmount;
  }
  return true;
}, 'Minimum amount must be less than or equal to maximum amount');

// Bulk tithe generation schema
export const bulkTitheGenerationSchema = z.object({
  month: monthNumber,
  year: yearNumber,
  percentage: z.number().positive().max(1, 'Percentage must be between 0 and 1'),
  member_ids: z.array(z.number().int().positive()).optional(), // If not provided, generate for all eligible members
  overwrite_existing: z.boolean().optional().default(false)
});

// Tithe payment marking schema
export const tithePaymentSchema = z.object({
  tithe_ids: z.array(z.number().int().positive()).min(1, 'At least one tithe ID is required'),
  paid_date: validDate,
  payment_method: z.string().min(1, 'Payment method is required').max(50, 'Payment method is too long').optional(),
  notes: z.string().max(500, 'Notes are too long').optional()
});

// Financial report schemas
export const financialReportSchema = z.object({
  type: z.enum(['donation_summary', 'tithe_summary', 'member_giving', 'category_breakdown', 'monthly_summary']),
  startDate: validDate,
  endDate: validDate,
  member_ids: z.array(z.number().int().positive()).optional(),
  categories: z.array(z.string()).optional(),
  include_unpaid_tithes: z.boolean().optional().default(false),
  group_by: z.enum(['month', 'quarter', 'year', 'category', 'member']).optional(),
  format: z.enum(['json', 'csv', 'xlsx']).optional().default('json')
}).refine((data) => {
  return new Date(data.startDate) <= new Date(data.endDate);
}, 'Start date must be before or equal to end date');

// Member giving summary schema
export const memberGivingSummarySchema = z.object({
  member_id: z.number().int().positive('Member ID is required'),
  startDate: validDate.optional(),
  endDate: validDate.optional(),
  include_tithes: z.boolean().optional().default(true),
  include_donations: z.boolean().optional().default(true)
}).refine((data) => {
  if (data.startDate && data.endDate) {
    return new Date(data.startDate) <= new Date(data.endDate);
  }
  return true;
}, 'Start date must be before or equal to end date');

// Export type definitions for use in components
export type DonationCreateData = z.infer<typeof donationCreateSchema>;
export type DonationUpdateData = z.infer<typeof donationUpdateSchema>;
export type DonationSearchParams = z.infer<typeof donationSearchSchema>;

export type TitheCreateData = z.infer<typeof titheCreateSchema>;
export type TitheUpdateData = z.infer<typeof titheUpdateSchema>;
export type TitheSearchParams = z.infer<typeof titheSearchSchema>;

export type BulkTitheGenerationData = z.infer<typeof bulkTitheGenerationSchema>;
export type TithePaymentData = z.infer<typeof tithePaymentSchema>;
export type FinancialReportParams = z.infer<typeof financialReportSchema>;
export type MemberGivingSummaryParams = z.infer<typeof memberGivingSummarySchema>;
