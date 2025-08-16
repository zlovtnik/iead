import { apiClient } from './client.js';
import type { PaginatedResponse, Donation } from './types.js';

// Re-export Donation type for convenience
export type { Donation } from './types.js';

export interface DonationCreateData {
  member_id: number;
  amount: number;
  donation_date: string;
  category?: string;
  notes?: string;
}

export interface DonationUpdateData {
  amount?: number;
  donation_date?: string;
  category?: string;
  notes?: string;
}

export interface DonationSearchParams {
  query?: string;
  member_id?: number;
  category?: string;
  startDate?: string;
  endDate?: string;
  minAmount?: number;
  maxAmount?: number;
  sortBy?: 'donation_date' | 'amount' | 'member_name' | 'category' | 'created_at';
  sortOrder?: 'asc' | 'desc';
  page?: number;
  limit?: number;
}

export interface DonationListResponse extends PaginatedResponse<Donation> {}

export interface DonationSummary {
  total_donations: number;
  total_amount: number;
  average_amount: number;
  largest_donation: number;
  categories: {
    category: string;
    count: number;
    total_amount: number;
  }[];
  monthly_totals: {
    month: string;
    count: number;
    total_amount: number;
  }[];
}

export interface MemberDonationHistory {
  member_id: number;
  total_donations: number;
  total_amount: number;
  average_amount: number;
  first_donation_date?: string;
  last_donation_date?: string;
  donations: Donation[];
  monthly_summary: {
    month: string;
    count: number;
    total_amount: number;
  }[];
}

export class DonationsApi {
  /**
   * Get paginated list of donations with optional search and filters
   */
  static async getDonations(params?: DonationSearchParams): Promise<DonationListResponse> {
    const searchParams = new URLSearchParams();
    
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          searchParams.append(key, String(value));
        }
      });
    }
    
    const queryString = searchParams.toString();
    const url = queryString ? `/donations?${queryString}` : '/donations';
    return apiClient.get<DonationListResponse>(url);
  }

  /**
   * Get a single donation by ID
   */
  static async getDonation(id: number): Promise<Donation> {
    return apiClient.get<Donation>(`/donations/${id}`);
  }

  /**
   * Create a new donation
   */
  static async createDonation(data: DonationCreateData): Promise<Donation> {
    return apiClient.post<Donation>('/donations', data);
  }

  /**
   * Update an existing donation
   */
  static async updateDonation(id: number, data: DonationUpdateData): Promise<Donation> {
    return apiClient.put<Donation>(`/donations/${id}`, data);
  }

  /**
   * Delete a donation
   */
  static async deleteDonation(id: number): Promise<void> {
    return apiClient.delete<void>(`/donations/${id}`);
  }

  /**
   * Get donations for a specific member
   */
  static async getMemberDonations(memberId: number, params?: Omit<DonationSearchParams, 'member_id'>): Promise<MemberDonationHistory> {
    const searchParams = new URLSearchParams();
    
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          searchParams.append(key, String(value));
        }
      });
    }
    
    const queryString = searchParams.toString();
    const url = queryString ? `/members/${memberId}/donations?${queryString}` : `/members/${memberId}/donations`;
    return apiClient.get<MemberDonationHistory>(url);
  }

  /**
   * Get donation summary statistics
   */
  static async getDonationSummary(startDate?: string, endDate?: string, category?: string): Promise<DonationSummary> {
    const params = new URLSearchParams();
    if (startDate) params.append('startDate', startDate);
    if (endDate) params.append('endDate', endDate);
    if (category) params.append('category', category);
    
    const queryString = params.toString();
    const url = queryString ? `/donations/summary?${queryString}` : '/donations/summary';
    return apiClient.get<DonationSummary>(url);
  }

  /**
   * Get donation categories
   */
  static async getDonationCategories(): Promise<string[]> {
    return apiClient.get<string[]>('/donations/categories');
  }

  /**
   * Get top donors for a period
   */
  static async getTopDonors(params: {
    startDate: string;
    endDate: string;
    limit?: number;
  }): Promise<{
    member_id: number;
    member_name: string;
    total_donations: number;
    total_amount: number;
    average_amount: number;
  }[]> {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) searchParams.append(key, String(value));
    });
    
    return apiClient.get(`/donations/top-donors?${searchParams.toString()}`);
  }

  /**
   * Get donation trends (monthly/yearly breakdown)
   */
  static async getDonationTrends(params: {
    startDate: string;
    endDate: string;
    groupBy?: 'month' | 'quarter' | 'year';
    category?: string;
  }): Promise<{
    period: string;
    count: number;
    total_amount: number;
    average_amount: number;
  }[]> {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) searchParams.append(key, String(value));
    });
    
    return apiClient.get(`/donations/trends?${searchParams.toString()}`);
  }

  /**
   * Export donations data
   */
  static async exportDonations(format: 'csv' | 'xlsx' = 'csv', filters?: DonationSearchParams): Promise<Blob> {
    const params = new URLSearchParams({ format });
    
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          params.append(key, String(value));
        }
      });
    }
    
    return apiClient.get<Blob>(`/donations/export?${params.toString()}`, {
      responseType: 'blob'
    });
  }

  /**
   * Create multiple donations in bulk
   */
  static async createBulkDonations(donations: DonationCreateData[]): Promise<Donation[]> {
    return apiClient.post<Donation[]>('/donations/bulk', { donations });
  }

  /**
   * Get donation statistics for dashboard
   */
  static async getDonationStats(period: 'week' | 'month' | 'quarter' | 'year' = 'month'): Promise<{
    current_period: {
      total_amount: number;
      count: number;
      average_amount: number;
    };
    previous_period: {
      total_amount: number;
      count: number;
      average_amount: number;
    };
    growth_percentage: number;
    top_categories: {
      category: string;
      amount: number;
      percentage: number;
    }[];
  }> {
    return apiClient.get(`/donations/stats?period=${period}`);
  }

  /**
   * Search donations by amount range
   */
  static async searchDonationsByAmount(minAmount: number, maxAmount: number): Promise<Donation[]> {
    const params = new URLSearchParams({
      minAmount: String(minAmount),
      maxAmount: String(maxAmount)
    });
    
    return apiClient.get(`/donations/search/amount?${params.toString()}`);
  }

  /**
   * Get recent donations
   */
  static async getRecentDonations(limit: number = 10): Promise<Donation[]> {
    return apiClient.get(`/donations/recent?limit=${limit}`);
  }
}

// Export singleton instances
export const donationsApi = new DonationsApi();
