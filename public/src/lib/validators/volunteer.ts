import { z } from 'zod';
import { requiredString, optionalString, positiveNumber, nonNegativeNumber, dateString } from './common.js';

/**
 * Volunteer-related validation schemas
 */

export const volunteerStatusSchema = z.enum(['active', 'inactive', 'completed']);

export const volunteerRoleSchema = z.enum([
  'Event Coordinator',
  'Setup Team',
  'Cleanup Crew',
  'Usher',
  'Greeter',
  'Audio/Visual Tech',
  'Childcare',
  'Kitchen Helper',
  'Security',
  'Parking Attendant',
  'Translation',
  'Music Ministry',
  'Prayer Team',
  'General Helper',
  'Other'
]).or(requiredString('Volunteer role is required'));

export const volunteerSchema = z.object({
  member_id: positiveNumber,
  event_id: positiveNumber.optional(),
  role: volunteerRoleSchema,
  hours: nonNegativeNumber.default(0),
  notes: optionalString,
  status: volunteerStatusSchema.default('active'),
  start_date: dateString,
  end_date: dateString.optional(),
}).refine(
  (data) => {
    // If both start and end dates are provided, end should be after start
    if (data.start_date && data.end_date) {
      return new Date(data.end_date) >= new Date(data.start_date);
    }
    return true;
  },
  {
    message: 'End date must be after or equal to start date',
    path: ['end_date']
  }
);

export const volunteerCreateSchema = volunteerSchema;

export const volunteerUpdateSchema = z
  .object({
    member_id: positiveNumber.optional(),
    event_id: positiveNumber.optional(),
    role: volunteerRoleSchema.optional(),
    hours: nonNegativeNumber.optional(),
    notes: optionalString, // already optional by definition
    status: volunteerStatusSchema.optional(),
    start_date: dateString.optional(),
    end_date: dateString.optional(),
  })
  .extend({ id: positiveNumber })
  .refine(
    (data) => {
      if (data.start_date && data.end_date) {
        return new Date(data.end_date) >= new Date(data.start_date);
      }
      return true;
    },
    {
      message: 'End date must be after or equal to start date',
      path: ['end_date'],
    }
  );

export const volunteerSearchSchema = z.object({
  query: optionalString,
  sortBy: z.enum(['role', 'hours', 'start_date', 'created_at']).default('start_date'),
  sortOrder: z.enum(['asc', 'desc']).default('desc'),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

export const volunteerFiltersSchema = z.object({
  member_id: z.coerce.number().int().positive().optional(),
  event_id: z.coerce.number().int().positive().optional(),
  status: volunteerStatusSchema.optional(),
  role: volunteerRoleSchema.optional(),
  minHours: z.coerce.number().min(0).optional(),
  maxHours: z.coerce.number().min(0).optional(),
  startDateAfter: dateString.optional(),
  startDateBefore: dateString.optional(),
}).refine(
  (data) => {
    // If both min and max hours are provided, min should be less than max
    if (data.minHours !== undefined && data.maxHours !== undefined) {
      return data.minHours <= data.maxHours;
    }
    return true;
  },
  {
    message: 'Minimum hours must be less than or equal to maximum hours',
    path: ['minHours']
  }
).refine(
  (data) => {
    // If both start date filters are provided, after should be before before
    if (data.startDateAfter && data.startDateBefore) {
      return new Date(data.startDateAfter) <= new Date(data.startDateBefore);
    }
    return true;
  },
  {
    message: 'Start date after must be before or equal to start date before',
    path: ['startDateAfter']
  }
);

export const volunteerAssignmentSchema = z.object({
  member_id: positiveNumber,
  event_id: positiveNumber,
  role: volunteerRoleSchema,
  expected_hours: nonNegativeNumber.optional(),
  notes: optionalString,
});

export const volunteerCompletionSchema = z.object({
  actual_hours: nonNegativeNumber,
  completion_notes: optionalString,
});

export const volunteerHoursCalculationSchema = z.object({
  startDate: dateString.optional(),
  endDate: dateString.optional(),
}).refine(
  (data) => {
    // If both dates are provided, start should be before end
    if (data.startDate && data.endDate) {
      return new Date(data.startDate) <= new Date(data.endDate);
    }
    return true;
  },
  {
    message: 'Start date must be before or equal to end date',
    path: ['startDate']
  }
);

// Type exports for use in components
export type VolunteerFormData = z.infer<typeof volunteerSchema>;
export type VolunteerSearchParams = z.infer<typeof volunteerSearchSchema>;
export type VolunteerFilters = z.infer<typeof volunteerFiltersSchema>;
export type VolunteerStatus = z.infer<typeof volunteerStatusSchema>;
export type VolunteerRole = z.infer<typeof volunteerRoleSchema>;
export type VolunteerAssignment = z.infer<typeof volunteerAssignmentSchema>;
export type VolunteerCompletion = z.infer<typeof volunteerCompletionSchema>;
export type VolunteerHoursCalculation = z.infer<typeof volunteerHoursCalculationSchema>;
