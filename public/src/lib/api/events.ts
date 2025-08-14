import { apiClient } from './client.js';
import type { PaginatedResponse } from './types.js';

export interface Event {
  id: number;
  title: string;
  description?: string;
  start_date: string;
  end_date?: string;
  location?: string;
  created_at: string;
  // Computed fields
  attendeeCount?: number;
  volunteerCount?: number;
  isUpcoming?: boolean;
  isPast?: boolean;
}

export interface EventFormData {
  title: string;
  description?: string;
  start_date: string;
  end_date?: string;
  location?: string;
}

export interface EventSearchParams {
  query?: string;
  sortBy?: 'title' | 'start_date' | 'created_at';
  sortOrder?: 'asc' | 'desc';
  page?: number;
  limit?: number;
}

export interface EventFilters {
  startAfter?: string;
  startBefore?: string;
  hasDescription?: boolean;
  hasLocation?: boolean;
  hasEndDate?: boolean;
}

export interface EventListResponse extends PaginatedResponse<Event> {}

export interface AttendanceRecord {
  id: number;
  event_id: number;
  member_id: number;
  attendance_date: string;
  created_at: string;
  // Relations
  member?: {
    id: number;
    name: string;
    email: string;
  };
}

export interface VolunteerAssignment {
  id: number;
  event_id: number;
  member_id: number;
  role: string;
  estimated_hours: number;
  actual_hours?: number;
  created_at: string;
  // Relations
  member?: {
    id: number;
    name: string;
    email: string;
  };
}

export interface EventStats {
  totalAttendees: number;
  totalVolunteers: number;
  totalVolunteerHours: number;
  attendanceRate?: number;
}

export class EventsApi {
  /**
   * Get paginated list of events with optional search and filters
   */
  static async getEvents(params?: EventSearchParams & EventFilters): Promise<EventListResponse> {
    const searchParams = new URLSearchParams();
    
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          searchParams.append(key, String(value));
        }
      });
    }
    
    const queryString = searchParams.toString();
    const url = queryString ? `/events?${queryString}` : '/events';
    return apiClient.get<EventListResponse>(url);
  }

  /**
   * Get a single event by ID
   */
  static async getEvent(id: number): Promise<Event> {
    return apiClient.get<Event>(`/events/${id}`);
  }

  /**
   * Create a new event
   */
  static async createEvent(eventData: EventFormData): Promise<Event> {
    return apiClient.post<Event>('/events', eventData);
  }

  /**
   * Update an existing event
   */
  static async updateEvent(id: number, eventData: Partial<EventFormData>): Promise<Event> {
    return apiClient.put<Event>(`/events/${id}`, eventData);
  }

  /**
   * Delete an event
   */
  static async deleteEvent(id: number): Promise<void> {
    return apiClient.delete<void>(`/events/${id}`);
  }

  /**
   * Search events by title or description
   */
  static async searchEvents(query: string, limit = 10): Promise<Event[]> {
    const params = new URLSearchParams({
      query,
      limit: String(limit)
    });
    
    const response = await apiClient.get<EventListResponse>(`/events/search?${params.toString()}`);
    return response.data;
  }

  /**
   * Get events for a specific date range (for calendar view)
   */
  static async getEventsInRange(startDate: string, endDate: string): Promise<Event[]> {
    const params = new URLSearchParams({
      startAfter: startDate,
      startBefore: endDate,
      limit: '1000' // Get all events in range
    });
    
    const response = await apiClient.get<EventListResponse>(`/events?${params.toString()}`);
    return response.data;
  }

  /**
   * Get upcoming events (next 7 days by default)
   */
  static async getUpcomingEvents(days = 7): Promise<Event[]> {
    const startDate = new Date().toISOString().split('T')[0];
    const endDate = new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    
    return this.getEventsInRange(startDate, endDate);
  }

  /**
   * Get event statistics
   */
  static async getEventStats(id: number): Promise<EventStats> {
    return apiClient.get<EventStats>(`/events/${id}/stats`);
  }

  /**
   * Get attendance records for an event
   */
  static async getEventAttendance(eventId: number): Promise<AttendanceRecord[]> {
    return apiClient.get<AttendanceRecord[]>(`/events/${eventId}/attendance`);
  }

  /**
   * Record attendance for multiple members at an event
   */
  static async recordBulkAttendance(eventId: number, memberIds: number[], attendanceDate?: string): Promise<AttendanceRecord[]> {
    const data = {
      member_ids: memberIds,
      attendance_date: attendanceDate || new Date().toISOString().split('T')[0]
    };
    
    return apiClient.post<AttendanceRecord[]>(`/events/${eventId}/attendance/bulk`, data);
  }

  /**
   * Remove attendance record
   */
  static async removeAttendance(eventId: number, memberId: number): Promise<void> {
    return apiClient.delete<void>(`/events/${eventId}/attendance/${memberId}`);
  }

  /**
   * Get volunteer assignments for an event
   */
  static async getEventVolunteers(eventId: number): Promise<VolunteerAssignment[]> {
    return apiClient.get<VolunteerAssignment[]>(`/events/${eventId}/volunteers`);
  }

  /**
   * Assign a volunteer to an event
   */
  static async assignVolunteer(assignment: {
    event_id: number;
    member_id: number;
    role: string;
    estimated_hours: number;
  }): Promise<VolunteerAssignment> {
    return apiClient.post<VolunteerAssignment>(`/events/${assignment.event_id}/volunteers`, assignment);
  }

  /**
   * Update volunteer assignment
   */
  static async updateVolunteerAssignment(
    eventId: number, 
    assignmentId: number, 
    data: { role?: string; estimated_hours?: number; actual_hours?: number }
  ): Promise<VolunteerAssignment> {
    return apiClient.put<VolunteerAssignment>(`/events/${eventId}/volunteers/${assignmentId}`, data);
  }

  /**
   * Remove volunteer assignment
   */
  static async removeVolunteerAssignment(eventId: number, assignmentId: number): Promise<void> {
    return apiClient.delete<void>(`/events/${eventId}/volunteers/${assignmentId}`);
  }

  /**
   * Export events data
   */
  static async exportEvents(format: 'csv' | 'xlsx' = 'csv', filters?: EventFilters): Promise<Blob> {
    const params = new URLSearchParams({ format });
    
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          params.append(key, String(value));
        }
      });
    }
    
    const response = await apiClient.get<Blob>(`/events/export?${params.toString()}`, {
      responseType: 'blob'
    });
    
    return response;
  }
}
