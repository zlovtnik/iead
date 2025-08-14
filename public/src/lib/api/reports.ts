// Report API client functions
import { apiClient } from './client.js';
import type { ApiResponse } from './types.js';

// Report data types
export interface DashboardMetrics {
  totalMembers: number;
  activeMembers: number;
  upcomingEvents: number;
  monthlyDonations: number;
  monthlyTithes: number;
  activeVolunteers: number;
  averageAttendance: number;
}

export interface AttendanceReport {
  eventId: number;
  eventTitle: string;
  eventDate: string;
  totalAttendees: number;
  attendanceRate: number;
  memberAttendance: {
    memberId: number;
    memberName: string;
    attended: boolean;
  }[];
}

export interface DonationSummary {
  totalDonations: number;
  donationsByCategory: {
    category: string;
    amount: number;
    count: number;
  }[];
  donationsByMonth: {
    month: string;
    amount: number;
    count: number;
  }[];
  topDonors: {
    memberId: number;
    memberName: string;
    totalAmount: number;
    donationCount: number;
  }[];
}

export interface FinancialReport {
  donations: DonationSummary;
  tithes: {
    totalTithes: number;
    paidTithes: number;
    unpaidTithes: number;
    tithesByMonth: {
      month: string;
      year: number;
      totalAmount: number;
      paidAmount: number;
      unpaidAmount: number;
    }[];
  };
  summary: {
    totalIncome: number;
    monthlyAverage: number;
    yearOverYearGrowth: number;
  };
}

export interface VolunteerReport {
  totalVolunteers: number;
  activeVolunteers: number;
  totalHours: number;
  volunteersByEvent: {
    eventId: number;
    eventTitle: string;
    volunteerCount: number;
    totalHours: number;
  }[];
  topVolunteers: {
    memberId: number;
    memberName: string;
    totalHours: number;
    eventCount: number;
  }[];
}

export interface MemberReport {
  totalMembers: number;
  newMembersThisMonth: number;
  membersByJoinDate: {
    month: string;
    count: number;
  }[];
  memberEngagement: {
    memberId: number;
    memberName: string;
    attendanceRate: number;
    donationTotal: number;
    volunteerHours: number;
    engagementScore: number;
  }[];
}

export interface ReportFilters {
  startDate?: string;
  endDate?: string;
  memberId?: number;
  eventId?: number;
  category?: string;
  limit?: number;
}

// API client functions
export const reportsApi = {
  // Dashboard metrics
  async getDashboardMetrics(): Promise<DashboardMetrics> {
    const response = await apiClient.get<ApiResponse<DashboardMetrics>>('/api/reports/dashboard');
    return response.data;
  },

  // Attendance reports
  async getAttendanceReport(filters: ReportFilters = {}): Promise<AttendanceReport[]> {
    const params = new URLSearchParams();
    if (filters.startDate) params.append('startDate', filters.startDate);
    if (filters.endDate) params.append('endDate', filters.endDate);
    if (filters.eventId) params.append('eventId', filters.eventId.toString());
    
    const response = await apiClient.get<ApiResponse<AttendanceReport[]>>(`/api/reports/attendance?${params}`);
    return response.data;
  },

  // Financial reports
  async getFinancialReport(filters: ReportFilters = {}): Promise<FinancialReport> {
    const params = new URLSearchParams();
    if (filters.startDate) params.append('startDate', filters.startDate);
    if (filters.endDate) params.append('endDate', filters.endDate);
    
    const response = await apiClient.get<ApiResponse<FinancialReport>>(`/api/reports/financial?${params}`);
    return response.data;
  },

  // Donation summary
  async getDonationSummary(filters: ReportFilters = {}): Promise<DonationSummary> {
    const params = new URLSearchParams();
    if (filters.startDate) params.append('startDate', filters.startDate);
    if (filters.endDate) params.append('endDate', filters.endDate);
    if (filters.category) params.append('category', filters.category);
    if (filters.limit) params.append('limit', filters.limit.toString());
    
    const response = await apiClient.get<ApiResponse<DonationSummary>>(`/api/reports/donations?${params}`);
    return response.data;
  },

  // Volunteer reports
  async getVolunteerReport(filters: ReportFilters = {}): Promise<VolunteerReport> {
    const params = new URLSearchParams();
    if (filters.startDate) params.append('startDate', filters.startDate);
    if (filters.endDate) params.append('endDate', filters.endDate);
    
    const response = await apiClient.get<ApiResponse<VolunteerReport>>(`/api/reports/volunteers?${params}`);
    return response.data;
  },

  // Member reports
  async getMemberReport(filters: ReportFilters = {}): Promise<MemberReport> {
    const params = new URLSearchParams();
    if (filters.startDate) params.append('startDate', filters.startDate);
    if (filters.endDate) params.append('endDate', filters.endDate);
    
    const response = await apiClient.get<ApiResponse<MemberReport>>(`/api/reports/members?${params}`);
    return response.data;
  },

  // Export reports
  async exportReport(reportType: string, format: 'pdf' | 'csv', filters: ReportFilters = {}): Promise<Blob> {
    const params = new URLSearchParams();
    params.append('format', format);
    if (filters.startDate) params.append('startDate', filters.startDate);
    if (filters.endDate) params.append('endDate', filters.endDate);
    if (filters.memberId) params.append('memberId', filters.memberId.toString());
    if (filters.eventId) params.append('eventId', filters.eventId.toString());
    if (filters.category) params.append('category', filters.category);
    
    const response = await apiClient.get(`/api/reports/${reportType}/export?${params}`, {
      responseType: 'blob'
    });
    return response as Blob;
  }
};