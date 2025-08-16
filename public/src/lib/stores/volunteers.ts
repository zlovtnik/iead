import { writable, derived } from 'svelte/store';
import { VolunteersApi, type Volunteer, type VolunteerFormData, type VolunteerSearchParams, type VolunteerFilters, type VolunteerHoursReport, type VolunteerHistory } from '../api/volunteers.js';
import { handleApiError } from '../utils/error-handling.js';
import { toastStore } from './ui.js';

interface VolunteersState {
  volunteers: Volunteer[];
  currentVolunteer: Volunteer | null;
  loading: boolean;
  error: string | null;
  totalCount: number;
  currentPage: number;
  pageSize: number;
  searchQuery: string;
  filters: VolunteerFilters;
  sortBy: string;
  sortOrder: 'asc' | 'desc';
}

const initialState: VolunteersState = {
  volunteers: [],
  currentVolunteer: null,
  loading: false,
  error: null,
  totalCount: 0,
  currentPage: 1,
  pageSize: 20,
  searchQuery: '',
  filters: {},
  sortBy: 'created_at',
  sortOrder: 'desc'
};

// Main volunteers store
const volunteersStore = writable<VolunteersState>(initialState);

export const volunteers = {
  subscribe: volunteersStore.subscribe,

  // Actions
  async loadVolunteers() {
    volunteersStore.update(state => ({ ...state, loading: true, error: null }));
    
    try {
      const { searchQuery, filters, sortBy, sortOrder, currentPage, pageSize } = this.getState();
      const params: VolunteerSearchParams & VolunteerFilters = {
        query: searchQuery || undefined,
        sortBy: sortBy as any,
        sortOrder,
        page: currentPage,
        limit: pageSize,
        ...filters
      };

      const response = await VolunteersApi.getVolunteers(params);

      volunteersStore.update(state => ({
        ...state,
        volunteers: response.data,
        totalCount: response.pagination.total,
        loading: false
      }));
    } catch (error) {
      const apiError = handleApiError(error);
      volunteersStore.update(state => ({
        ...state,
        loading: false,
        error: apiError.message
      }));
      toastStore.error(apiError.message);
    }
  },

  async createVolunteer(data: VolunteerFormData) {
    volunteersStore.update(state => ({ ...state, loading: true, error: null }));
    
    try {
      const newVolunteer = await VolunteersApi.createVolunteer(data);
      
      volunteersStore.update(state => ({
        ...state,
        volunteers: [newVolunteer, ...state.volunteers],
        totalCount: state.totalCount + 1,
        loading: false
      }));
      
      toastStore.success('Volunteer assignment created successfully');
      return newVolunteer;
    } catch (error) {
      const apiError = handleApiError(error);
      volunteersStore.update(state => ({
        ...state,
        loading: false,
        error: apiError.message
      }));
      toastStore.error(apiError.message);
      throw error;
    }
  },

  async updateVolunteer(id: number, data: Partial<VolunteerFormData>) {
    volunteersStore.update(state => ({ ...state, loading: true, error: null }));
    
    try {
      const updatedVolunteer = await VolunteersApi.updateVolunteer(id, data);
      
      volunteersStore.update(state => ({
        ...state,
        volunteers: state.volunteers.map(v => 
          v.id === id ? updatedVolunteer : v
        ),
        currentVolunteer: state.currentVolunteer?.id === id ? updatedVolunteer : state.currentVolunteer,
        loading: false
      }));
      
      toastStore.success('Volunteer assignment updated successfully');
      return updatedVolunteer;
    } catch (error) {
      const apiError = handleApiError(error);
      volunteersStore.update(state => ({
        ...state,
        loading: false,
        error: apiError.message
      }));
      toastStore.error(apiError.message);
      throw error;
    }
  },

  async deleteVolunteer(id: number) {
    volunteersStore.update(state => ({ ...state, loading: true, error: null }));
    
    try {
      await VolunteersApi.deleteVolunteer(id);
      
      volunteersStore.update(state => ({
        ...state,
        volunteers: state.volunteers.filter(v => v.id !== id),
        totalCount: state.totalCount - 1,
        currentVolunteer: state.currentVolunteer?.id === id ? null : state.currentVolunteer,
        loading: false
      }));
      
      toastStore.success('Volunteer assignment deleted successfully');
    } catch (error) {
      const apiError = handleApiError(error);
      volunteersStore.update(state => ({
        ...state,
        loading: false,
        error: apiError.message
      }));
      toastStore.error(apiError.message);
      throw error;
    }
  },

  async getVolunteer(id: number) {
    volunteersStore.update(state => ({ ...state, loading: true, error: null }));
    
    try {
      const volunteer = await VolunteersApi.getVolunteer(id);
      
      volunteersStore.update(state => ({
        ...state,
        currentVolunteer: volunteer,
        loading: false
      }));
      
      return volunteer;
    } catch (error) {
      const apiError = handleApiError(error);
      volunteersStore.update(state => ({
        ...state,
        loading: false,
        error: apiError.message
      }));
      toastStore.error(apiError.message);
      throw error;
    }
  },

  async completeAssignment(id: number, actualHours: number, notes?: string) {
    try {
      const updatedVolunteer = await VolunteersApi.completeVolunteerAssignment(id, {
        actual_hours: actualHours,
        completion_notes: notes
      });
      
      volunteersStore.update(state => ({
        ...state,
        volunteers: state.volunteers.map(v => 
          v.id === id ? updatedVolunteer : v
        ),
        currentVolunteer: state.currentVolunteer?.id === id ? updatedVolunteer : state.currentVolunteer
      }));
      
      toastStore.success('Volunteer assignment completed successfully');
      return updatedVolunteer;
    } catch (error) {
      const apiError = handleApiError(error);
      toastStore.error(apiError.message);
      throw error;
    }
  },

  // Search and filter methods
  setSearchQuery(query: string) {
    volunteersStore.update(state => ({
      ...state,
      searchQuery: query,
      currentPage: 1
    }));
  },

  setFilters(filters: Partial<VolunteerFilters>) {
    volunteersStore.update(state => ({
      ...state,
      filters: { ...state.filters, ...filters },
      currentPage: 1
    }));
  },

  clearFilters() {
    volunteersStore.update(state => ({
      ...state,
      filters: {},
      searchQuery: '',
      currentPage: 1
    }));
  },

  setSorting(sortBy: string, sortOrder: 'asc' | 'desc') {
    volunteersStore.update(state => ({
      ...state,
      sortBy,
      sortOrder,
      currentPage: 1
    }));
  },

  setPage(page: number) {
    volunteersStore.update(state => ({
      ...state,
      currentPage: page
    }));
  },

  setPageSize(size: number) {
    volunteersStore.update(state => ({
      ...state,
      pageSize: size,
      currentPage: 1
    }));
  },

  // Utility methods
  getState() {
    let currentState: VolunteersState;
    volunteersStore.subscribe(state => currentState = state)();
    return currentState!;
  },

  clearError() {
    volunteersStore.update(state => ({
      ...state,
      error: null
    }));
  },

  reset() {
    volunteersStore.set(initialState);
  }
};

// Derived stores for computed values
export const volunteersByStatus = derived(
  volunteersStore,
  $volunteers => {
    const grouped = $volunteers.volunteers.reduce((acc, volunteer) => {
      const status = volunteer.status;
      if (!acc[status]) acc[status] = [];
      acc[status].push(volunteer);
      return acc;
    }, {} as Record<string, Volunteer[]>);
    
    return grouped;
  }
);

export const volunteerStats = derived(
  volunteersStore,
  $volunteers => {
    const totalVolunteers = $volunteers.volunteers.length;
    const activeVolunteers = $volunteers.volunteers.filter(v => v.status === 'active').length;
    const completedVolunteers = $volunteers.volunteers.filter(v => v.status === 'completed').length;
    const totalHours = $volunteers.volunteers.reduce((sum, v) => sum + v.hours, 0);
    const averageHours = totalVolunteers > 0 ? totalHours / totalVolunteers : 0;
    
    return {
      totalVolunteers,
      activeVolunteers,
      completedVolunteers,
      totalHours,
      averageHours: Math.round(averageHours * 100) / 100
    };
  }
);

export const hasActiveFilters = derived(
  volunteersStore,
  $volunteers => {
    return Object.keys($volunteers.filters).length > 0 || $volunteers.searchQuery.length > 0;
  }
);

// Volunteer hours store
const volunteerHoursStore = writable<{
  hoursReport: VolunteerHoursReport | null;
  history: VolunteerHistory[];
  loading: boolean;
  error: string | null;
}>({
  hoursReport: null,
  history: [],
  loading: false,
  error: null
});

export const volunteerHours = {
  subscribe: volunteerHoursStore.subscribe,

  async loadHoursReport(memberId: number) {
    volunteerHoursStore.update(state => ({ ...state, loading: true, error: null }));
    
    try {
      const report = await VolunteersApi.getVolunteerHours(memberId);
      
      volunteerHoursStore.update(state => ({
        ...state,
        hoursReport: report,
        loading: false
      }));
      
      return report;
    } catch (error) {
      const apiError = handleApiError(error);
      volunteerHoursStore.update(state => ({
        ...state,
        loading: false,
        error: apiError.message
      }));
      throw error;
    }
  },

  async loadHistory(memberId: number, params?: { limit?: number; status?: any }) {
    volunteerHoursStore.update(state => ({ ...state, loading: true, error: null }));
    
    try {
      const history = await VolunteersApi.getVolunteerHistory(memberId, params);
      
      volunteerHoursStore.update(state => ({
        ...state,
        history,
        loading: false
      }));
      
      return history;
    } catch (error) {
      const apiError = handleApiError(error);
      volunteerHoursStore.update(state => ({
        ...state,
        loading: false,
        error: apiError.message
      }));
      throw error;
    }
  },

  reset() {
    volunteerHoursStore.set({
      hoursReport: null,
      history: [],
      loading: false,
      error: null
    });
  }
};
