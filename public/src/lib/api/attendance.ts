import { apiClient } from './client.js';
import type { PaginatedResponse } from './types.js';

export interface AttendanceRecord {
  id: number;
  event_id: number;
  member_id: number;
  attendance_date: string;
  notes?: string;
  created_at: string;
  updated_at: string;
  // Relations
  event?: {
    id: number;
    title: string;
    start_date: string;
    location?: string;
  };
  member?: {
    id: number;
    name: string;
    email: string;
  };
}

export interface AttendanceRecordData {
  event_id: number;
  member_id: number;
  attendance_date?: string;
  notes?: string;
}

export interface BulkAttendanceData {
  event_id: number;
  member_ids: number[];
  attendance_date?: string;
  notes?: string;
}

export interface AttendanceSearchParams {
  query?: string;
  event_id?: number;
  member_id?: number;
  sortBy?: 'attendance_date' | 'member_name' | 'event_title' | 'created_at';
  sortOrder?: 'asc' | 'desc';
  page?: number;
  limit?: number;
}

export interface AttendanceFilters {
  startDate?: string;
  endDate?: string;
  event_ids?: number[];
  member_ids?: number[];
  hasNotes?: boolean;
}

export interface AttendanceListResponse extends PaginatedResponse<AttendanceRecord> {}

export interface MemberAttendanceStats {
  member_id: number;
  total_events: number;
  attended_events: number;
  attendance_rate: number;
  first_attendance?: string;
  last_attendance?: string;
  streak_current: number;
  streak_longest: number;
  // Monthly breakdown
  monthly_stats: {
    month: string;
    attended: number;
    total_events: number;
    rate: number;
  }[];
}

export interface EventAttendanceStats {
  event_id: number;
  total_members: number;
  attended_members: number;
  attendance_rate: number;
  // Breakdown by member groups if applicable
  stats_by_group?: {
    group_name: string;
    attended: number;
    total: number;
    rate: number;
  }[];
}

export interface AttendanceReport {
  type: 'member_summary' | 'event_summary' | 'date_range' | 'member_detail';
  period: {
    start_date: string;
    end_date: string;
  };
  summary: {
    total_events: number;
    total_attendance_records: number;
    unique_attendees: number;
    average_attendance_rate: number;
  };
  data: any[]; // Depends on report type
  generated_at: string;
}

export class AttendanceApi {
  /**
   * Get paginated list of attendance records with optional search and filters
   */
  static async getAttendanceRecords(params?: AttendanceSearchParams & AttendanceFilters): Promise<AttendanceListResponse> {
    const searchParams = new URLSearchParams();
    
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          if (Array.isArray(value)) {
            value.forEach(v => searchParams.append(key, String(v)));
          } else {
            searchParams.append(key, String(value));
          }
        }
      });
    }
    
    const queryString = searchParams.toString();
    const url = queryString ? `/attendance?${queryString}` : '/attendance';
    return apiClient.get<AttendanceListResponse>(url);
  }

  /**
   * Get a single attendance record by ID
   */
  static async getAttendanceRecord(id: number): Promise<AttendanceRecord> {
    return apiClient.get<AttendanceRecord>(`/attendance/${id}`);
  }

  /**
   * Create a new attendance record
   */
  static async createAttendanceRecord(data: AttendanceRecordData): Promise<AttendanceRecord> {
    return apiClient.post<AttendanceRecord>('/attendance', data);
  }

  /**
   * Create multiple attendance records in bulk
   */
  static async createBulkAttendance(data: BulkAttendanceData): Promise<AttendanceRecord[]> {
    return apiClient.post<AttendanceRecord[]>('/attendance/bulk', data);
  }

  /**
   * Update an existing attendance record
   */
  static async updateAttendanceRecord(id: number, data: Partial<AttendanceRecordData>): Promise<AttendanceRecord> {
    return apiClient.put<AttendanceRecord>(`/attendance/${id}`, data);
  }

  /**
   * Delete an attendance record
   */
  static async deleteAttendanceRecord(id: number): Promise<void> {
    return apiClient.delete<void>(`/attendance/${id}`);
  }

  /**
   * Get attendance records for a specific event
   */
  static async getEventAttendance(eventId: number, params?: Omit<AttendanceSearchParams, 'event_id'>): Promise<AttendanceRecord[]> {
    const searchParams = new URLSearchParams();
    
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          searchParams.append(key, String(value));
        }
      });
    }
    
    const queryString = searchParams.toString();
    const url = queryString ? `/events/${eventId}/attendance?${queryString}` : `/events/${eventId}/attendance`;
    return apiClient.get<AttendanceRecord[]>(url);
  }

  /**
   * Get attendance records for a specific member
   */
  static async getMemberAttendance(memberId: number, params?: Omit<AttendanceSearchParams, 'member_id'>): Promise<AttendanceRecord[]> {
    const searchParams = new URLSearchParams();
    
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          searchParams.append(key, String(value));
        }
      });
    }
    
    const queryString = searchParams.toString();
    const url = queryString ? `/members/${memberId}/attendance?${queryString}` : `/members/${memberId}/attendance`;
    return apiClient.get<AttendanceRecord[]>(url);
  }

  /**
   * Get attendance statistics for a member
   */
  static async getMemberAttendanceStats(memberId: number, startDate?: string, endDate?: string): Promise<MemberAttendanceStats> {
    const params = new URLSearchParams();
    if (startDate) params.append('startDate', startDate);
    if (endDate) params.append('endDate', endDate);
    
    const queryString = params.toString();
    const url = queryString ? `/members/${memberId}/attendance/stats?${queryString}` : `/members/${memberId}/attendance/stats`;
    return apiClient.get<MemberAttendanceStats>(url);
  }

  /**
   * Get attendance statistics for an event
   */
  static async getEventAttendanceStats(eventId: number): Promise<EventAttendanceStats> {
    return apiClient.get<EventAttendanceStats>(`/events/${eventId}/attendance/stats`);
  }

  /**
   * Generate attendance report
   */
  static async generateAttendanceReport(params: {
    type: 'member_summary' | 'event_summary' | 'date_range' | 'member_detail';
    startDate: string;
    endDate: string;
    member_ids?: number[];
    event_ids?: number[];
    format?: 'json' | 'csv' | 'xlsx';
    include_statistics?: boolean;
  }): Promise<AttendanceReport | Blob> {
    const { format = 'json', ...reportParams } = params;
    
    if (format === 'json') {
      return apiClient.post<AttendanceReport>('/attendance/reports', reportParams);
    } else {
      // For CSV/Excel, return blob
      return apiClient.post<Blob>('/attendance/reports', { ...reportParams, format }, {
        responseType: 'blob'
      });
    }
  }

  /**
   * Get attendance summary for date range
   */
  static async getAttendanceSummary(startDate: string, endDate: string): Promise<{
    total_events: number;
    total_attendance: number;
    unique_members: number;
    average_attendance_rate: number;
    top_attended_events: { event_id: number; title: string; attendance_count: number }[];
    most_active_members: { member_id: number; name: string; attendance_count: number }[];
  }> {
    const params = new URLSearchParams({ startDate, endDate });
    return apiClient.get(`/attendance/summary?${params.toString()}`);
  }

  /**
   * Check if member attended specific event
   */
  static async checkMemberEventAttendance(memberId: number, eventId: number): Promise<AttendanceRecord | null> {
    try {
      return await apiClient.get<AttendanceRecord>(`/attendance/check?member_id=${memberId}&event_id=${eventId}`);
    } catch (error: any) {
      if (error.response?.status === 404) {
        return null;
      }
      throw error;
    }
  }

  /**
   * Get members who attended multiple events (for follow-up)
   */
  static async getRegularAttendees(params: {
    startDate: string;
    endDate: string;
    min_attendance_count?: number;
    min_attendance_rate?: number;
  }): Promise<{
    member_id: number;
    name: string;
    email: string;
    attendance_count: number;
    attendance_rate: number;
  }[]> {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) searchParams.append(key, String(value));
    });
    
    return apiClient.get(`/attendance/regular-attendees?${searchParams.toString()}`);
  }

  /**
   * Get members who haven't attended recently (for follow-up)
   */
  static async getAbsentMembers(params: {
    days_since_last_attendance?: number;
    min_previous_attendance?: number;
  }): Promise<{
    member_id: number;
    name: string;
    email: string;
    last_attendance_date?: string;
    days_since_attendance: number;
    total_past_attendance: number;
  }[]> {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) searchParams.append(key, String(value));
    });
    
    return apiClient.get(`/attendance/absent-members?${searchParams.toString()}`);
  }

  /**
   * Export attendance data
   */
  static async exportAttendance(format: 'csv' | 'xlsx' = 'csv', filters?: AttendanceFilters): Promise<Blob> {
    const params = new URLSearchParams({ format });
    
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          if (Array.isArray(value)) {
            value.forEach(v => params.append(key, String(v)));
          } else {
            params.append(key, String(value));
          }
        }
      });
    }
    
    return apiClient.get<Blob>(`/attendance/export?${params.toString()}`, {
      responseType: 'blob'
    });
  }
}
