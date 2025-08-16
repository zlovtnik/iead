import { apiClient } from './client.js';
import type { PaginatedResponse } from './types.js';

export interface Member {
  id: number;
  name: string;
  email: string;
  phone?: string;
  salary?: number;
  created_at: string;
  // Computed fields
  totalDonations?: number;
  attendanceRate?: number;
  volunteerHours?: number;
}

export interface MemberFormData {
  name: string;
  email: string;
  phone?: string;
  salary?: number;
}

export interface MemberSearchParams {
  query?: string;
  sortBy?: 'name' | 'email' | 'created_at';
  sortOrder?: 'asc' | 'desc';
  page?: number;
  limit?: number;
}

export interface MemberFilters {
  hasEmail?: boolean;
  hasPhone?: boolean;
  hasSalary?: boolean;
  minSalary?: number;
  maxSalary?: number;
  createdAfter?: string;
  createdBefore?: string;
}

export interface MemberListResponse extends PaginatedResponse<Member> {}

export class MembersApi {
  /**
   * Get paginated list of members with optional search and filters
   */
  static async getMembers(params?: MemberSearchParams & MemberFilters): Promise<MemberListResponse> {
    const searchParams = new URLSearchParams();
    
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          searchParams.append(key, String(value));
        }
      });
    }
    
    const url = `/members${searchParams.toString() ? `?${searchParams.toString()}` : ''}`;
    return apiClient.get<MemberListResponse>(url);
  }

  /**
   * Get a single member by ID
   */
  static async getMember(id: number): Promise<Member> {
    return apiClient.get<Member>(`/members/${id}`);
  }

  /**
   * Create a new member
   */
  static async createMember(memberData: MemberFormData): Promise<Member> {
    return apiClient.post<Member>('/members', memberData);
  }

  /**
   * Update an existing member
   */
  static async updateMember(id: number, memberData: Partial<MemberFormData>): Promise<Member> {
    return apiClient.put<Member>(`/members/${id}`, memberData);
  }

  /**
   * Delete a member
   */
  static async deleteMember(id: number): Promise<void> {
    return apiClient.delete<void>(`/members/${id}`);
  }

  /**
   * Search members by name or email
   */
  static async searchMembers(query: string, limit = 10): Promise<Member[]> {
    const params = new URLSearchParams({
      query,
      limit: String(limit)
    });
    
    const response = await apiClient.get<MemberListResponse>(`/members/search?${params.toString()}`);
    return response.data;
  }

  /**
   * Get member statistics (donations, attendance, volunteer hours)
   */
  static async getMemberStats(id: number): Promise<{
    totalDonations: number;
    attendanceRate: number;
    volunteerHours: number;
    lastAttendance?: string;
    lastDonation?: string;
  }> {
    return apiClient.get<any>(`/members/${id}/stats`);
  }

  /**
   * Get members with upcoming birthdays
   */
  static async getUpcomingBirthdays(days = 30): Promise<Member[]> {
    const params = new URLSearchParams({ days: String(days) });
    const response = await apiClient.get<{ data: Member[] }>(`/members/birthdays?${params.toString()}`);
    return response.data;
  }

  /**
   * Export members data
   */
  static async exportMembers(format: 'csv' | 'xlsx' = 'csv', filters?: MemberFilters): Promise<Blob> {
    const params = new URLSearchParams({ format });
    
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          params.append(key, String(value));
        }
      });
    }
    
    const response = await apiClient.get<Blob>(`/members/export?${params.toString()}`, {
      responseType: 'blob'
    });
    
    return response;
  }
}