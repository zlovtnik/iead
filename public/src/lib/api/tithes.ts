import { apiClient } from './client.js';
import type { PaginatedResponse, Tithe } from './types.js';

// Re-export Tithe type for convenience
export type { Tithe } from './types.js';

export interface TitheCreateData {
  member_id: number;
  amount: number;
  month: number;
  year: number;
  is_paid?: boolean;
  paid_date?: string;
}

export interface TitheUpdateData {
  amount?: number;
  month?: number;
  year?: number;
  is_paid?: boolean;
  paid_date?: string;
  payment_method?: string;
  notes?: string;
}

export interface TitheSearchParams {
  query?: string;
  member_id?: number;
  month?: number;
  year?: number;
  is_paid?: boolean;
  startDate?: string;
  endDate?: string;
  minAmount?: number;
  maxAmount?: number;
  sortBy?: 'month' | 'year' | 'amount' | 'member_name' | 'paid_date' | 'created_at';
  sortOrder?: 'asc' | 'desc';
  page?: number;
  limit?: number;
}

export interface TitheListResponse extends PaginatedResponse<Tithe> {}

export interface BulkTitheGenerationData {
  month: number;
  year: number;
  percentage: number;
  member_ids?: number[];
  overwrite_existing?: boolean;
}

export interface TithePaymentData {
  tithe_ids: number[];
  paid_date: string;
  payment_method?: string;
  notes?: string;
}

export interface TitheSummary {
  total_tithes: number;
  total_amount: number;
  paid_amount: number;
  unpaid_amount: number;
  paid_count: number;
  unpaid_count: number;
  payment_rate: number;
  monthly_breakdown: {
    month: number;
    year: number;
    total_amount: number;
    paid_amount: number;
    unpaid_amount: number;
    payment_rate: number;
  }[];
}

export interface MemberTitheHistory {
  member_id: number;
  total_tithes: number;
  total_amount: number;
  paid_amount: number;
  unpaid_amount: number;
  payment_rate: number;
  current_salary?: number;
  tithes: Tithe[];
  yearly_summary: {
    year: number;
    total_amount: number;
    paid_amount: number;
    months_completed: number;
  }[];
}

export interface TitheCalculationResult {
  member_id: number;
  member_name: string;
  salary: number;
  percentage: number;
  calculated_amount: number;
  existing_tithe_id?: number;
  existing_amount?: number;
}

export class TithesApi {
  /**
   * Get paginated list of tithes with optional search and filters
   */
  static async getTithes(params?: TitheSearchParams): Promise<TitheListResponse> {
    const searchParams = new URLSearchParams();
    
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          searchParams.append(key, String(value));
        }
      });
    }
    
    const queryString = searchParams.toString();
    const url = queryString ? `/tithes?${queryString}` : '/tithes';
    return apiClient.get<TitheListResponse>(url);
  }

  /**
   * Get a single tithe by ID
   */
  static async getTithe(id: number): Promise<Tithe> {
    return apiClient.get<Tithe>(`/tithes/${id}`);
  }

  /**
   * Create a new tithe
   */
  static async createTithe(data: TitheCreateData): Promise<Tithe> {
    return apiClient.post<Tithe>('/tithes', data);
  }

  /**
   * Update an existing tithe
   */
  static async updateTithe(id: number, data: TitheUpdateData): Promise<Tithe> {
    return apiClient.put<Tithe>(`/tithes/${id}`, data);
  }

  /**
   * Delete a tithe
   */
  static async deleteTithe(id: number): Promise<void> {
    return apiClient.delete<void>(`/tithes/${id}`);
  }

  /**
   * Get tithes for a specific member
   */
  static async getMemberTithes(memberId: number, params?: Omit<TitheSearchParams, 'member_id'>): Promise<MemberTitheHistory> {
    const searchParams = new URLSearchParams();
    
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          searchParams.append(key, String(value));
        }
      });
    }
    
    const queryString = searchParams.toString();
    const url = queryString ? `/members/${memberId}/tithes?${queryString}` : `/members/${memberId}/tithes`;
    return apiClient.get<MemberTitheHistory>(url);
  }

  /**
   * Generate tithes for a specific month/year
   */
  static async generateMonthlyTithes(data: BulkTitheGenerationData): Promise<TitheCalculationResult[]> {
    return apiClient.post<TitheCalculationResult[]>('/tithes/generate', data);
  }

  /**
   * Calculate potential tithes for preview (without saving)
   */
  static async calculateTithes(data: BulkTitheGenerationData): Promise<TitheCalculationResult[]> {
    return apiClient.post<TitheCalculationResult[]>('/tithes/calculate', data);
  }

  /**
   * Mark tithes as paid
   */
  static async markTithesAsPaid(data: TithePaymentData): Promise<Tithe[]> {
    return apiClient.post<Tithe[]>('/tithes/mark-paid', data);
  }

  /**
   * Mark tithe as unpaid
   */
  static async markTitheAsUnpaid(id: number): Promise<Tithe> {
    return apiClient.post<Tithe>(`/tithes/${id}/mark-unpaid`);
  }

  /**
   * Get tithe summary statistics
   */
  static async getTitheSummary(startDate?: string, endDate?: string): Promise<TitheSummary> {
    const params = new URLSearchParams();
    if (startDate) params.append('startDate', startDate);
    if (endDate) params.append('endDate', endDate);
    
    const queryString = params.toString();
    const url = queryString ? `/tithes/summary?${queryString}` : '/tithes/summary';
    return apiClient.get<TitheSummary>(url);
  }

  /**
   * Get unpaid tithes
   */
  static async getUnpaidTithes(params?: {
    member_id?: number;
    year?: number;
    month?: number;
  }): Promise<Tithe[]> {
    const searchParams = new URLSearchParams({ is_paid: 'false' });
    
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined) searchParams.append(key, String(value));
      });
    }
    
    return apiClient.get(`/tithes?${searchParams.toString()}`);
  }

  /**
   * Get tithe payment history
   */
  static async getTithePaymentHistory(params: {
    startDate: string;
    endDate: string;
    member_id?: number;
  }): Promise<{
    tithe_id: number;
    member_name: string;
    amount: number;
    month: number;
    year: number;
    paid_date: string;
    payment_method?: string;
  }[]> {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) searchParams.append(key, String(value));
    });
    
    return apiClient.get(`/tithes/payment-history?${searchParams.toString()}`);
  }

  /**
   * Get tithe compliance report (members who haven't paid)
   */
  static async getTitheComplianceReport(year: number, month?: number): Promise<{
    member_id: number;
    member_name: string;
    salary: number;
    expected_amount: number;
    actual_amount: number;
    months_behind: number;
    last_payment_date?: string;
  }[]> {
    const params = new URLSearchParams({ year: String(year) });
    if (month) params.append('month', String(month));
    
    return apiClient.get(`/tithes/compliance?${params.toString()}`);
  }

  /**
   * Get tithe statistics for dashboard
   */
  static async getTitheStats(period: 'month' | 'quarter' | 'year' = 'month'): Promise<{
    current_period: {
      total_amount: number;
      paid_amount: number;
      unpaid_amount: number;
      payment_rate: number;
    };
    previous_period: {
      total_amount: number;
      paid_amount: number;
      unpaid_amount: number;
      payment_rate: number;
    };
    growth_percentage: number;
    compliance_rate: number;
  }> {
    return apiClient.get(`/tithes/stats?period=${period}`);
  }

  /**
   * Export tithes data
   */
  static async exportTithes(format: 'csv' | 'xlsx' = 'csv', filters?: TitheSearchParams): Promise<Blob> {
    const params = new URLSearchParams({ format });
    
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          params.append(key, String(value));
        }
      });
    }
    
    return apiClient.get<Blob>(`/tithes/export?${params.toString()}`, {
      responseType: 'blob'
    });
  }

  /**
   * Get tithe configuration (default percentage, etc.)
   */
  static async getTitheConfig(): Promise<{
    default_percentage: number;
    auto_generate_enabled: boolean;
    payment_grace_period_days: number;
  }> {
    return apiClient.get('/tithes/config');
  }

  /**
   * Update tithe configuration
   */
  static async updateTitheConfig(config: {
    default_percentage?: number;
    auto_generate_enabled?: boolean;
    payment_grace_period_days?: number;
  }): Promise<void> {
    return apiClient.put('/tithes/config', config);
  }

  /**
   * Get recent tithe payments
   */
  static async getRecentPayments(limit: number = 10): Promise<Tithe[]> {
    return apiClient.get(`/tithes/recent-payments?limit=${limit}`);
  }
}

// Export singleton instances
export const tithesApi = new TithesApi();
