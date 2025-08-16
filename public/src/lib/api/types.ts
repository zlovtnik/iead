// Base API response types and error handling utilities

export interface ApiResponse<T = any> {
  data: T;
  message?: string;
  success: boolean;
}

export interface ApiError {
  type: 'network' | 'validation' | 'authorization' | 'server';
  message: string;
  details?: Record<string, string[]>;
  statusCode?: number;
}

export interface ValidationError {
  field: string;
  message: string;
  code: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface LoginCredentials {
  username: string;
  password: string;
}

export interface AuthTokens {
  token: string;
  refreshToken: string;
}

export interface RefreshTokenRequest {
  refreshToken: string;
}

// Financial management types
export type PaymentMethod = 'cash' | 'check' | 'credit_card' | 'bank_transfer' | 'mobile_payment';

export interface Donation {
  id: number;
  member_id: number;
  amount: number;
  donation_date: string;
  payment_method: PaymentMethod;
  category?: string;
  description?: string;
  receipt_number?: string;
  is_tax_deductible: boolean;
  created_at: string;
  updated_at: string;
}

export interface Tithe {
  id: number;
  member_id: number;
  amount: number;
  month: number;
  year: number;
  calculated_income?: number;
  is_paid: boolean;
  paid_date?: string;
  payment_method?: PaymentMethod;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface DonationSearchParams {
  member_id?: number;
  start_date?: string;
  end_date?: string;
  min_amount?: number;
  max_amount?: number;
  payment_method?: string;
  category?: string;
  is_tax_deductible?: boolean;
  page?: number;
  per_page?: number;
}

export interface TitheSearchParams {
  member_id?: number;
  year?: number;
  month?: number;
  is_paid?: boolean;
  start_date?: string;
  end_date?: string;
  page?: number;
  per_page?: number;
}

export interface TitheGenerationRequest {
  year: number;
  month: number;
  member_ids?: number[];
  default_income_percentage?: number;
  recalculate_existing?: boolean;
}

export interface PaymentMarkRequest {
  tithe_ids: number[];
  paid_date: string;
  payment_method?: PaymentMethod;
  notes?: string;
}

export interface ComplianceReportParams {
  year?: number;
  month?: number;
  member_id?: number;
  start_date?: string;
  end_date?: string;
}

export interface DonationSummary {
  total_amount: number;
  total_count: number;
  average_amount: number;
  by_category: Record<string, { amount: number; count: number }>;
  by_payment_method: Record<string, { amount: number; count: number }>;
  by_month: Array<{ month: string; amount: number; count: number }>;
}

export interface TitheTrends {
  compliance_rate: number;
  total_expected: number;
  total_paid: number;
  by_month: Array<{ 
    month: string; 
    expected: number; 
    paid: number; 
    compliance_rate: number 
  }>;
}

export interface FinancialReport {
  period: string;
  donations: DonationSummary;
  tithes: TitheTrends;
  total_giving: number;
  member_count: number;
  top_donors: Array<{
    member_id: number;
    member_name: string;
    total_amount: number;
    donation_count: number;
  }>;
}

export class ApiException extends Error {
  public readonly type: ApiError['type'];
  public readonly statusCode?: number;
  public readonly details?: Record<string, string[]>;

  constructor(error: ApiError) {
    super(error.message);
    this.name = 'ApiException';
    this.type = error.type;
    this.statusCode = error.statusCode;
    this.details = error.details;
  }
}