import { z } from 'zod';
import { optionalString, dateString } from './common.js';

/**
 * Attendance-related validation schemas
 */

export const attendanceRecordSchema = z.object({
  event_id: z.number().int().positive('Invalid event ID'),
  member_id: z.number().int().positive('Invalid member ID'),
  attendance_date: dateString.optional(),
  notes: optionalString,
});

export const bulkAttendanceSchema = z.object({
  event_id: z.number().int().positive('Invalid event ID'),
  member_ids: z.array(z.number().int().positive()).min(1, 'At least one member must be selected'),
  attendance_date: dateString.optional(),
  notes: optionalString,
});

export const attendanceUpdateSchema = z.object({
  attendance_date: dateString.optional(),
  notes: optionalString,
});

export const attendanceSearchSchema = z.object({
  query: optionalString,
  event_id: z.number().int().positive().optional(),
  member_id: z.number().int().positive().optional(),
  sortBy: z.enum(['attendance_date', 'member_name', 'event_title', 'created_at']).default('attendance_date'),
  sortOrder: z.enum(['asc', 'desc']).default('desc'),
  page: z.number().int().positive().default(1),
  limit: z.number().int().positive().max(100).default(20),
});

export const attendanceFiltersSchema = z.object({
  startDate: dateString.optional(),
  endDate: dateString.optional(),
  event_ids: z.array(z.number().int().positive()).optional(),
  member_ids: z.array(z.number().int().positive()).optional(),
  hasNotes: z.boolean().optional(),
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

export const attendanceReportSchema = z.object({
  type: z.enum(['member_summary', 'event_summary', 'date_range', 'member_detail']),
  startDate: dateString,
  endDate: dateString,
  member_ids: z.array(z.number().int().positive()).optional(),
  event_ids: z.array(z.number().int().positive()).optional(),
  format: z.enum(['json', 'csv', 'xlsx']).default('json'),
  include_statistics: z.boolean().default(true),
}).refine(
  (data) => {
    return new Date(data.startDate) <= new Date(data.endDate);
  },
  {
    message: 'Start date must be before or equal to end date',
    path: ['startDate']
  }
);

export const memberAttendanceStatsSchema = z.object({
  member_id: z.number().int().positive('Invalid member ID'),
  startDate: dateString.optional(),
  endDate: dateString.optional(),
});

// Export types for TypeScript inference
export type AttendanceRecordData = z.infer<typeof attendanceRecordSchema>;
export type BulkAttendanceData = z.infer<typeof bulkAttendanceSchema>;
export type AttendanceUpdateData = z.infer<typeof attendanceUpdateSchema>;
export type AttendanceSearchParams = z.infer<typeof attendanceSearchSchema>;
export type AttendanceFilters = z.infer<typeof attendanceFiltersSchema>;
export type AttendanceReportParams = z.infer<typeof attendanceReportSchema>;
export type MemberAttendanceStatsParams = z.infer<typeof memberAttendanceStatsSchema>;
