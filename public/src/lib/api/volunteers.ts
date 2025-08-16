import { apiClient } from './client.js';
import type { PaginatedResponse } from './types.js';

export type VolunteerStatus = 'active' | 'inactive' | 'completed';

export interface Volunteer {
  id: number;
  member_id: number;
  event_id?: number;
  role: string;
  hours: number;
  notes?: string;
  status: VolunteerStatus;
  start_date: string;
  end_date?: string;
  created_at: string;
  // Joined fields from backend
  member_name?: string;
  event_title?: string;
}

export interface VolunteerFormData {
  member_id: number;
  event_id?: number;
  role: string;
  hours?: number;
  notes?: string;
  status: VolunteerStatus;
  start_date: string;
  end_date?: string;
}

export interface VolunteerSearchParams {
  query?: string;
  sortBy?: 'role' | 'hours' | 'start_date' | 'created_at';
  sortOrder?: 'asc' | 'desc';
  page?: number;
  limit?: number;
}

export interface VolunteerFilters {
  member_id?: number;
  event_id?: number;
  status?: VolunteerStatus;
  role?: string;
  minHours?: number;
  maxHours?: number;
  startDateAfter?: string;
  startDateBefore?: string;
}

export interface VolunteerListResponse extends PaginatedResponse<Volunteer> {}

export interface VolunteerHoursReport {
  member_id: number;
  member_name: string;
  total_hours: number;
  active_assignments: number;
  completed_assignments: number;
}

export interface VolunteerHistory {
  volunteer: Volunteer;
  event_title?: string;
  duration_days?: number;
}

export class VolunteersApi {
  /**
   * Get paginated list of volunteers with optional search and filters
   */
  static async getVolunteers(params?: VolunteerSearchParams & VolunteerFilters): Promise<VolunteerListResponse> {
    const searchParams = new URLSearchParams();
    
    if (params?.query) searchParams.append('query', params.query);
    if (params?.sortBy) searchParams.append('sortBy', params.sortBy);
    if (params?.sortOrder) searchParams.append('sortOrder', params.sortOrder);
    if (params?.page) searchParams.append('page', params.page.toString());
    if (params?.limit) searchParams.append('limit', params.limit.toString());
    if (params?.member_id) searchParams.append('member_id', params.member_id.toString());
    if (params?.event_id) searchParams.append('event_id', params.event_id.toString());
    if (params?.status) searchParams.append('status', params.status);
    if (params?.role) searchParams.append('role', params.role);
    if (params?.minHours) searchParams.append('minHours', params.minHours.toString());
    if (params?.maxHours) searchParams.append('maxHours', params.maxHours.toString());
    if (params?.startDateAfter) searchParams.append('startDateAfter', params.startDateAfter);
    if (params?.startDateBefore) searchParams.append('startDateBefore', params.startDateBefore);

    return apiClient.get<VolunteerListResponse>(`/volunteers?${searchParams.toString()}`);
  }

  /**
   * Get volunteer by ID
   */
  static async getVolunteer(id: number): Promise<Volunteer> {
    return apiClient.get<Volunteer>(`/volunteers/${id}`);
  }

  /**
   * Create new volunteer assignment
   */
  static async createVolunteer(data: VolunteerFormData): Promise<Volunteer> {
    return apiClient.post<Volunteer>('/volunteers', data);
  }

  /**
   * Update volunteer assignment
   */
  static async updateVolunteer(id: number, data: Partial<VolunteerFormData>): Promise<Volunteer> {
    return apiClient.put<Volunteer>(`/volunteers/${id}`, data);
  }

  /**
   * Delete volunteer assignment
   */
  static async deleteVolunteer(id: number): Promise<void> {
    return apiClient.delete<void>(`/volunteers/${id}`);
  }

  /**
   * Get volunteers by member ID
   */
  static async getVolunteersByMember(memberId: number): Promise<Volunteer[]> {
    return apiClient.get<Volunteer[]>(`/members/${memberId}/volunteers`);
  }

  /**
   * Get volunteers by event ID
   */
  static async getVolunteersByEvent(eventId: number): Promise<Volunteer[]> {
    return apiClient.get<Volunteer[]>(`/events/${eventId}/volunteers`);
  }

  /**
   * Get volunteer hours report for a member
   */
  static async getVolunteerHours(memberId: number): Promise<VolunteerHoursReport> {
    return apiClient.get<VolunteerHoursReport>(`/members/${memberId}/volunteer-hours`);
  }

  /**
   * Get volunteer history for a member
   */
  static async getVolunteerHistory(memberId: number, params?: {
    limit?: number;
    status?: VolunteerStatus;
  }): Promise<VolunteerHistory[]> {
    const searchParams = new URLSearchParams();
    if (params?.limit) searchParams.append('limit', params.limit.toString());
    if (params?.status) searchParams.append('status', params.status);

    return apiClient.get<VolunteerHistory[]>(
      `/members/${memberId}/volunteer-history?${searchParams.toString()}`
    );
  }

  /**
   * Get available volunteer roles
   */
  static async getVolunteerRoles(): Promise<string[]> {
    return apiClient.get<string[]>('/volunteers/roles');
  }

  /**
   * Calculate total volunteer hours for a member
   */
  static async calculateMemberHours(memberId: number, dateRange?: {
    startDate?: string;
    endDate?: string;
  }): Promise<{ totalHours: number; assignmentCount: number }> {
    const searchParams = new URLSearchParams();
    if (dateRange?.startDate) searchParams.append('startDate', dateRange.startDate);
    if (dateRange?.endDate) searchParams.append('endDate', dateRange.endDate);

    return apiClient.get<{ totalHours: number; assignmentCount: number }>(
      `/members/${memberId}/volunteer-hours/calculate?${searchParams.toString()}`
    );
  }

  /**
   * Assign volunteer to role for specific event
   */
  static async assignVolunteerToEvent(data: {
    member_id: number;
    event_id: number;
    role: string;
    expected_hours?: number;
    notes?: string;
  }): Promise<Volunteer> {
    return apiClient.post<Volunteer>('/volunteers/assign-to-event', data);
  }

  /**
   * Complete volunteer assignment and record actual hours
   */
  static async completeVolunteerAssignment(id: number, data: {
    actual_hours: number;
    completion_notes?: string;
  }): Promise<Volunteer> {
    return apiClient.put<Volunteer>(`/volunteers/${id}/complete`, data);
  }
}
