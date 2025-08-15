import { writable, derived } from 'svelte/store';
import type { Donation, Tithe, DonationSearchParams, TitheSearchParams, TitheGenerationRequest, PaymentMarkRequest, ComplianceReportParams } from '$lib/api/types';
import { DonationsApi } from '$lib/api/donations';
import { TithesApi } from '$lib/api/tithes';
import { handleApiError } from '$lib/utils/error-handling';
import { user } from './auth';

// Donation store
export const donations = writable<Donation[]>([]);
export const donationsLoading = writable(false);
export const donationsError = writable<string | null>(null);

// Tithe store
export const tithes = writable<Tithe[]>([]);
export const tithesLoading = writable(false);
export const tithesError = writable<string | null>(null);

// Pagination stores
export const donationsPagination = writable({
  currentPage: 1,
  pageSize: 10,
  total: 0,
  totalPages: 0
});

export const tithesPagination = writable({
  currentPage: 1,
  pageSize: 10,
  total: 0,
  totalPages: 0
});

// Derived stores for computed values
export const totalDonations = derived(donations, ($donations) => 
  $donations.reduce((sum, donation) => sum + donation.amount, 0)
);

export const totalPaidTithes = derived(tithes, ($tithes) => 
  $tithes.filter(t => t.is_paid).reduce((sum, tithe) => sum + tithe.amount, 0)
);

export const unpaidTithes = derived(tithes, ($tithes) => 
  $tithes.filter(t => !t.is_paid)
);

export const titheComplianceRate = derived(tithes, ($tithes) => {
  if ($tithes.length === 0) return 0;
  const paidCount = $tithes.filter(t => t.is_paid).length;
  return (paidCount / $tithes.length) * 100;
});

// Donation actions
export const donationActions = {
  async fetchDonations(params: DonationSearchParams = {}) {
    donationsLoading.set(true);
    donationsError.set(null);
    
    try {
      const response = await DonationsApi.getDonations(params);
      donations.set(response.data);
      donationsPagination.set({
        currentPage: response.pagination.page,
        pageSize: response.pagination.limit,
        total: response.pagination.total,
        totalPages: response.pagination.totalPages
      });
    } catch (error) {
      const apiError = handleApiError(error);
      donationsError.set(apiError.message);
      console.error('Error fetching donations:', error);
    } finally {
      donationsLoading.set(false);
    }
  },

  async createDonation(donation: Omit<Donation, 'id' | 'created_at' | 'updated_at'>) {
    donationsLoading.set(true);
    donationsError.set(null);
    
    try {
      const newDonation = await DonationsApi.createDonation(donation);
      donations.update(current => [newDonation, ...current]);
      return newDonation;
    } catch (error) {
      const apiError = handleApiError(error);
      donationsError.set(apiError.message);
      console.error('Error creating donation:', error);
      throw error;
    } finally {
      donationsLoading.set(false);
    }
  },

  async updateDonation(id: number, updates: Partial<Donation>) {
    donationsLoading.set(true);
    donationsError.set(null);
    
    try {
      const updatedDonation = await DonationsApi.updateDonation(id, updates);
      donations.update(current => 
        current.map(d => d.id === id ? updatedDonation : d)
      );
      return updatedDonation;
    } catch (error) {
      const apiError = handleApiError(error);
      donationsError.set(apiError.message);
      console.error('Error updating donation:', error);
      throw error;
    } finally {
      donationsLoading.set(false);
    }
  },

  async deleteDonation(id: number) {
    donationsLoading.set(true);
    donationsError.set(null);
    
    try {
      await DonationsApi.deleteDonation(id);
      donations.update(current => current.filter(d => d.id !== id));
    } catch (error) {
      const apiError = handleApiError(error);
      donationsError.set(apiError.message);
      console.error('Error deleting donation:', error);
      throw error;
    } finally {
      donationsLoading.set(false);
    }
  },

  async getDonationSummary(startDate?: string, endDate?: string, category?: string) {
    try {
      return await DonationsApi.getDonationSummary(startDate, endDate, category);
    } catch (error) {
      const apiError = handleApiError(error);
      donationsError.set(apiError.message);
      console.error('Error fetching donation summary:', error);
      throw error;
    }
  },

  async getDonationTrends(params: { startDate: string; endDate: string; groupBy?: 'month' | 'year' | 'quarter'; category?: string }) {
    try {
      return await DonationsApi.getDonationTrends(params);
    } catch (error) {
      const apiError = handleApiError(error);
      donationsError.set(apiError.message);
      console.error('Error fetching donation trends:', error);
      throw error;
    }
  },

  async exportDonations(format: 'csv' | 'xlsx' = 'csv', filters?: DonationSearchParams) {
    try {
      return await DonationsApi.exportDonations(format, filters);
    } catch (error) {
      const apiError = handleApiError(error);
      donationsError.set(apiError.message);
      console.error('Error exporting donations:', error);
      throw error;
    }
  }
};

// Tithe actions
export const titheActions = {
  async fetchTithes(params: TitheSearchParams = {}) {
    tithesLoading.set(true);
    tithesError.set(null);
    
    try {
      const response = await TithesApi.getTithes(params);
      tithes.set(response.data);
      tithesPagination.set({
        currentPage: response.pagination.page,
        pageSize: response.pagination.limit,
        total: response.pagination.total,
        totalPages: response.pagination.totalPages
      });
    } catch (error) {
      const apiError = handleApiError(error);
      tithesError.set(apiError.message);
      console.error('Error fetching tithes:', error);
    } finally {
      tithesLoading.set(false);
    }
  },

  async createTithe(tithe: Omit<Tithe, 'id' | 'created_at' | 'updated_at'>) {
    tithesLoading.set(true);
    tithesError.set(null);
    
    try {
      const newTithe = await TithesApi.createTithe(tithe);
      tithes.update(current => [newTithe, ...current]);
      return newTithe;
    } catch (error) {
      const apiError = handleApiError(error);
      tithesError.set(apiError.message);
      console.error('Error creating tithe:', error);
      throw error;
    } finally {
      tithesLoading.set(false);
    }
  },

  async updateTithe(id: number, updates: Partial<Tithe>) {
    tithesLoading.set(true);
    tithesError.set(null);
    
    try {
      const updatedTithe = await TithesApi.updateTithe(id, updates);
      tithes.update(current => 
        current.map(t => t.id === id ? updatedTithe : t)
      );
      return updatedTithe;
    } catch (error) {
      const apiError = handleApiError(error);
      tithesError.set(apiError.message);
      console.error('Error updating tithe:', error);
      throw error;
    } finally {
      tithesLoading.set(false);
    }
  },

  async deleteTithe(id: number) {
    tithesLoading.set(true);
    tithesError.set(null);
    
    try {
      await TithesApi.deleteTithe(id);
      tithes.update(current => current.filter(t => t.id !== id));
    } catch (error) {
      const apiError = handleApiError(error);
      tithesError.set(apiError.message);
      console.error('Error deleting tithe:', error);
      throw error;
    } finally {
      tithesLoading.set(false);
    }
  },

  async generateMonthlyTithes(request: TitheGenerationRequest) {
    tithesLoading.set(true);
    tithesError.set(null);
    
    try {
      const response = await TithesApi.generateMonthlyTithes({
        month: request.month,
        year: request.year,
        percentage: request.default_income_percentage || 10,
        member_ids: request.member_ids,
        overwrite_existing: request.recalculate_existing
      });
      // Refresh the tithes list to include new ones
      await this.fetchTithes();
      return response;
    } catch (error) {
      const apiError = handleApiError(error);
      tithesError.set(apiError.message);
      console.error('Error generating monthly tithes:', error);
      throw error;
    } finally {
      tithesLoading.set(false);
    }
  },

  async markTithesPaid(request: PaymentMarkRequest) {
    tithesLoading.set(true);
    tithesError.set(null);
    
    try {
      const response = await TithesApi.markTithesAsPaid({
        tithe_ids: request.tithe_ids,
        paid_date: request.paid_date,
        payment_method: request.payment_method,
        notes: request.notes
      });
      // Update the local state
      tithes.update(current => 
        current.map(t => 
          request.tithe_ids.includes(t.id) 
            ? { ...t, is_paid: true, paid_date: request.paid_date }
            : t
        )
      );
      return response;
    } catch (error) {
      const apiError = handleApiError(error);
      tithesError.set(apiError.message);
      console.error('Error marking tithes as paid:', error);
      throw error;
    } finally {
      tithesLoading.set(false);
    }
  },

  async getComplianceReport(params: ComplianceReportParams) {
    try {
      return await TithesApi.getTitheComplianceReport(params.year || new Date().getFullYear(), params.month);
    } catch (error) {
      const apiError = handleApiError(error);
      tithesError.set(apiError.message);
      console.error('Error fetching compliance report:', error);
      throw error;
    }
  },

  async calculateTitheAmount(memberId: number, month: number, year: number) {
    try {
      // Use the calculation API through generateMonthlyTithes with specific member
      return await TithesApi.calculateTithes({
        member_ids: [memberId],
        month,
        year,
        percentage: 10 // Default 10% tithe
      });
    } catch (error) {
      const apiError = handleApiError(error);
      tithesError.set(apiError.message);
      console.error('Error calculating tithe amount:', error);
      throw error;
    }
  }
};

// Combined financial summary
export const financialSummary = derived(
  [donations, tithes],
  ([$donations, $tithes]) => {
    const totalDonationAmount = $donations.reduce((sum, d) => sum + d.amount, 0);
    const totalTitheAmount = $tithes.filter(t => t.is_paid).reduce((sum, t) => sum + t.amount, 0);
    const pendingTithes = $tithes.filter(t => !t.is_paid);
    const pendingTitheAmount = pendingTithes.reduce((sum, t) => sum + t.amount, 0);
    
    return {
      totalDonations: totalDonationAmount,
      totalTithes: totalTitheAmount,
      totalGiving: totalDonationAmount + totalTitheAmount,
      pendingTithes: pendingTithes.length,
      pendingTitheAmount,
      complianceRate: $tithes.length > 0 ? ($tithes.filter(t => t.is_paid).length / $tithes.length) * 100 : 0
    };
  }
);

// Clear all stores
export function clearFinancialStores() {
  donations.set([]);
  tithes.set([]);
  donationsError.set(null);
  tithesError.set(null);
  donationsPagination.set({
    currentPage: 1,
    pageSize: 10,
    total: 0,
    totalPages: 0
  });
  tithesPagination.set({
    currentPage: 1,
    pageSize: 10,
    total: 0,
    totalPages: 0
  });
}

// Auto-clear stores when user logs out
user.subscribe((currentUser) => {
  if (!currentUser) {
    clearFinancialStores();
  }
});
