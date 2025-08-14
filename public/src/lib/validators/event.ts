import { z } from 'zod';
import { requiredString, optionalString, dateString } from './common.js';

/**
 * Event-related validation schemas
 */

export const eventSchema = z.object({
  title: requiredString('Event title is required'),
  description: optionalString,
  start_date: dateString.refine(
    (date) => new Date(date) > new Date(),
    { message: 'Event start date must be in the future' }
  ),
  end_date: dateString.optional().refine(
    (date) => !date || new Date(date) > new Date(),
    { message: 'Event end date must be in the future' }
  ),
  location: optionalString,
}).refine(
  (data) => {
    // If both start and end dates are provided, end must be after start
    if (data.end_date && data.start_date) {
      return new Date(data.end_date) >= new Date(data.start_date);
    }
    return true;
  },
  {
    message: 'End date must be after start date',
    path: ['end_date']
  }
);

export const eventCreateSchema = eventSchema;

export const eventUpdateSchema = eventSchema.partial().extend({
  id: z.number().int().positive('Invalid event ID'),
});

export const eventSearchSchema = z.object({
  query: optionalString,
  sortBy: z.enum(['title', 'start_date', 'created_at']).default('start_date'),
  sortOrder: z.enum(['asc', 'desc']).default('asc'),
  page: z.number().int().positive().default(1),
  limit: z.number().int().positive().max(100).default(20),
});

export const eventFiltersSchema = z.object({
  startAfter: dateString.optional(),
  startBefore: dateString.optional(),
  hasDescription: z.boolean().optional(),
  hasLocation: z.boolean().optional(),
  hasEndDate: z.boolean().optional(),
}).refine(
  (data) => {
    // If both start filters are provided, startAfter should be before startBefore
    if (data.startAfter && data.startBefore) {
      return new Date(data.startAfter) <= new Date(data.startBefore);
    }
    return true;
  },
  {
    message: 'Start after date must be before start before date',
    path: ['startAfter']
  }
);

export const bulkAttendanceSchema = z.object({
  event_id: z.number().int().positive('Invalid event ID'),
  member_ids: z.array(z.number().int().positive()).min(1, 'At least one member must be selected'),
  attendance_date: dateString.optional(),
});

export const volunteerAssignmentSchema = z.object({
  event_id: z.number().int().positive('Invalid event ID'),
  member_id: z.number().int().positive('Invalid member ID'),
  role: requiredString('Volunteer role is required'),
  estimated_hours: z.number().min(0, 'Estimated hours must be non-negative').max(24, 'Estimated hours cannot exceed 24 per day'),
});

// Export types for TypeScript inference
export type EventFormData = z.infer<typeof eventSchema>;
export type EventCreateData = z.infer<typeof eventCreateSchema>;
export type EventUpdateData = z.infer<typeof eventUpdateSchema>;
export type EventSearchParams = z.infer<typeof eventSearchSchema>;
export type EventFilters = z.infer<typeof eventFiltersSchema>;
export type BulkAttendanceData = z.infer<typeof bulkAttendanceSchema>;
export type VolunteerAssignmentData = z.infer<typeof volunteerAssignmentSchema>;
