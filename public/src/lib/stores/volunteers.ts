import { writable, derived, get } from 'svelte/store';
import { VolunteersApi, type Volunteer, type VolunteerFormData, type VolunteerSearchParams, type VolunteerFilters, type VolunteerStatus, type VolunteerHoursReport, type VolunteerHistory } from '../api/volunteers.js';
import { ApiException } from '../api/types.js';

export interface VolunteersState {
  volunteers: Volunteer[];
  selectedVolunteer: Volunteer | null;
  isLoading: boolean;
  isCreating: boolean;
  isUpdating: boolean;
  isDeleting: boolean;
  error: string | null;
  searchQuery: string;
  filters: VolunteerFilters;
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
  sortBy: 'role' | 'hours' | 'start_date' | 'created_at';
  sortOrder: 'asc' | 'desc';
  availableRoles: string[];
  memberVolunteers: Record<number, Volunteer[]>;
  eventVolunteers: Record<number, Volunteer[]>;
  volunteerHours: Record<number, VolunteerHoursReport>;
  volunteerHistory: Record<number, VolunteerHistory[]>;
}

const initialState: VolunteersState = {
  volunteers: [],
  selectedVolunteer: null,
  isLoading: false,
  isCreating: false,
  isUpdating: false,
  isDeleting: false,
  error: null,
  searchQuery: '',
  filters: {},
  pagination: {
    page: 1,
    limit: 20,
    total: 0,
    totalPages: 0
  },
  sortBy: 'start_date',
  sortOrder: 'desc',
  availableRoles: [],
  memberVolunteers: {},
  eventVolunteers: {},
  volunteerHours: {},
  volunteerHistory: {}
};

// Create the writable store
const volunteersStore = writable<VolunteersState>(initialState);

/**
 * Volunteers store with actions for CRUD operations and search/filtering
 */
export const volunteers = {
  // Subscribe to the store
  subscribe: volunteersStore.subscribe,

  /**
   * Load volunteers with current search, filter, and pagination settings
   */
  async loadVolunteers(): Promise<void> {
    const state = get(volunteersStore);
    
    volunteersStore.update(s => ({ ...s, isLoading: true, error: null }));

    try {
      const params: VolunteerSearchParams & VolunteerFilters = {
        query: state.searchQuery || undefined,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        page: state.pagination.page,
        limit: state.pagination.limit,
        ...state.filters
      };

      const response = await VolunteersApi.getVolunteers(params);
      
      volunteersStore.update(s => ({
        ...s,
        volunteers: response.data,
        pagination: response.pagination,
        isLoading: false,
        error: null
      }));
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to load volunteers. Please try again.';
      
      volunteersStore.update(s => ({
        ...s,
        isLoading: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Load a specific volunteer by ID
   */
  async loadVolunteer(id: number): Promise<Volunteer> {
    volunteersStore.update(s => ({ ...s, isLoading: true, error: null }));

    try {
      const volunteer = await VolunteersApi.getVolunteer(id);
      
      volunteersStore.update(s => ({
        ...s,
        selectedVolunteer: volunteer,
        isLoading: false,
        error: null
      }));
      
      return volunteer;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to load volunteer. Please try again.';
      
      volunteersStore.update(s => ({
        ...s,
        isLoading: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Create a new volunteer assignment
   */
  async createVolunteer(volunteerData: VolunteerFormData): Promise<Volunteer> {
    volunteersStore.update(s => ({ ...s, isCreating: true, error: null }));

    try {
      const volunteer = await VolunteersApi.createVolunteer(volunteerData);
      
      volunteersStore.update(s => ({
        ...s,
        volunteers: [volunteer, ...s.volunteers],
        pagination: {
          ...s.pagination,
          total: s.pagination.total + 1
        },
        isCreating: false,
        error: null
      }));
      
      return volunteer;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to create volunteer assignment. Please try again.';
      
      volunteersStore.update(s => ({
        ...s,
        isCreating: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Update an existing volunteer assignment
   */
  async updateVolunteer(id: number, volunteerData: Partial<VolunteerFormData>): Promise<Volunteer> {
    volunteersStore.update(s => ({ ...s, isUpdating: true, error: null }));

    try {
      const updatedVolunteer = await VolunteersApi.updateVolunteer(id, volunteerData);
      
      volunteersStore.update(s => ({
        ...s,
        volunteers: s.volunteers.map(v => v.id === id ? updatedVolunteer : v),
        selectedVolunteer: s.selectedVolunteer?.id === id ? updatedVolunteer : s.selectedVolunteer,
        isUpdating: false,
        error: null
      }));
      
      return updatedVolunteer;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to update volunteer assignment. Please try again.';
      
      volunteersStore.update(s => ({
        ...s,
        isUpdating: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Delete a volunteer assignment
   */
  async deleteVolunteer(id: number): Promise<void> {
    volunteersStore.update(s => ({ ...s, isDeleting: true, error: null }));

    try {
      await VolunteersApi.deleteVolunteer(id);
      
      volunteersStore.update(s => ({
        ...s,
        volunteers: s.volunteers.filter(v => v.id !== id),
        selectedVolunteer: s.selectedVolunteer?.id === id ? null : s.selectedVolunteer,
        pagination: {
          ...s.pagination,
          total: Math.max(0, s.pagination.total - 1)
        },
        isDeleting: false,
        error: null
      }));
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to delete volunteer assignment. Please try again.';
      
      volunteersStore.update(s => ({
        ...s,
        isDeleting: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Load volunteers for a specific member
   */
  async loadMemberVolunteers(memberId: number): Promise<Volunteer[]> {
    try {
      const memberVolunteers = await VolunteersApi.getVolunteersByMember(memberId);
      
      volunteersStore.update(s => ({
        ...s,
        memberVolunteers: {
          ...s.memberVolunteers,
          [memberId]: memberVolunteers
        }
      }));
      
      return memberVolunteers;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to load member volunteers. Please try again.';
      
      volunteersStore.update(s => ({
        ...s,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Load volunteers for a specific event
   */
  async loadEventVolunteers(eventId: number): Promise<Volunteer[]> {
    try {
      const eventVolunteers = await VolunteersApi.getVolunteersByEvent(eventId);
      
      volunteersStore.update(s => ({
        ...s,
        eventVolunteers: {
          ...s.eventVolunteers,
          [eventId]: eventVolunteers
        }
      }));
      
      return eventVolunteers;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to load event volunteers. Please try again.';
      
      volunteersStore.update(s => ({
        ...s,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Load volunteer hours report for a member
   */
  async loadVolunteerHours(memberId: number): Promise<VolunteerHoursReport> {
    try {
      const hoursReport = await VolunteersApi.getVolunteerHours(memberId);
      
      volunteersStore.update(s => ({
        ...s,
        volunteerHours: {
          ...s.volunteerHours,
          [memberId]: hoursReport
        }
      }));
      
      return hoursReport;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to load volunteer hours. Please try again.';
      
      volunteersStore.update(s => ({
        ...s,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Load volunteer history for a member
   */
  async loadVolunteerHistory(memberId: number, params?: {
    limit?: number;
    status?: VolunteerStatus;
  }): Promise<VolunteerHistory[]> {
    try {
      const history = await VolunteersApi.getVolunteerHistory(memberId, params);
      
      volunteersStore.update(s => ({
        ...s,
        volunteerHistory: {
          ...s.volunteerHistory,
          [memberId]: history
        }
      }));
      
      return history;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to load volunteer history. Please try again.';
      
      volunteersStore.update(s => ({
        ...s,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Load available volunteer roles
   */
  async loadVolunteerRoles(): Promise<string[]> {
    try {
      const roles = await VolunteersApi.getVolunteerRoles();
      
      volunteersStore.update(s => ({
        ...s,
        availableRoles: roles
      }));
      
      return roles;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to load volunteer roles. Please try again.';
      
      volunteersStore.update(s => ({
        ...s,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Assign volunteer to event
   */
  async assignVolunteerToEvent(data: {
    member_id: number;
    event_id: number;
    role: string;
    expected_hours?: number;
    notes?: string;
  }): Promise<Volunteer> {
    volunteersStore.update(s => ({ ...s, isCreating: true, error: null }));

    try {
      const volunteer = await VolunteersApi.assignVolunteerToEvent(data);
      
      volunteersStore.update(s => ({
        ...s,
        volunteers: [volunteer, ...s.volunteers],
        eventVolunteers: {
          ...s.eventVolunteers,
          [data.event_id]: [volunteer, ...(s.eventVolunteers[data.event_id] || [])]
        },
        memberVolunteers: {
          ...s.memberVolunteers,
          [data.member_id]: [volunteer, ...(s.memberVolunteers[data.member_id] || [])]
        },
        isCreating: false,
        error: null
      }));
      
      return volunteer;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to assign volunteer to event. Please try again.';
      
      volunteersStore.update(s => ({
        ...s,
        isCreating: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Complete volunteer assignment
   */
  async completeVolunteerAssignment(id: number, data: {
    actual_hours: number;
    completion_notes?: string;
  }): Promise<Volunteer> {
    volunteersStore.update(s => ({ ...s, isUpdating: true, error: null }));

    try {
      const completedVolunteer = await VolunteersApi.completeVolunteerAssignment(id, data);
      
      volunteersStore.update(s => ({
        ...s,
        volunteers: s.volunteers.map(v => v.id === id ? completedVolunteer : v),
        selectedVolunteer: s.selectedVolunteer?.id === id ? completedVolunteer : s.selectedVolunteer,
        isUpdating: false,
        error: null
      }));
      
      return completedVolunteer;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to complete volunteer assignment. Please try again.';
      
      volunteersStore.update(s => ({
        ...s,
        isUpdating: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Set search query and trigger reload
   */
  async setSearchQuery(query: string): Promise<void> {
    volunteersStore.update(s => ({
      ...s,
      searchQuery: query,
      pagination: { ...s.pagination, page: 1 }
    }));
    
    await volunteers.loadVolunteers();
  },

  /**
   * Update filters and trigger reload
   */
  async setFilters(filters: VolunteerFilters): Promise<void> {
    volunteersStore.update(s => ({
      ...s,
      filters: { ...s.filters, ...filters },
      pagination: { ...s.pagination, page: 1 }
    }));
    
    await volunteers.loadVolunteers();
  },

  /**
   * Clear all filters and trigger reload
   */
  async clearFilters(): Promise<void> {
    volunteersStore.update(s => ({
      ...s,
      filters: {},
      searchQuery: '',
      pagination: { ...s.pagination, page: 1 }
    }));
    
    await volunteers.loadVolunteers();
  },

  /**
   * Set sort order and trigger reload
   */
  async setSorting(sortBy: 'role' | 'hours' | 'start_date' | 'created_at', sortOrder: 'asc' | 'desc'): Promise<void> {
    volunteersStore.update(s => ({
      ...s,
      sortBy,
      sortOrder,
      pagination: { ...s.pagination, page: 1 }
    }));
    
    await volunteers.loadVolunteers();
  },

  /**
   * Set current page and trigger reload
   */
  async setPage(page: number): Promise<void> {
    volunteersStore.update(s => ({
      ...s,
      pagination: { ...s.pagination, page }
    }));
    
    await volunteers.loadVolunteers();
  },

  /**
   * Set page size and trigger reload
   */
  async setPageSize(limit: number): Promise<void> {
    volunteersStore.update(s => ({
      ...s,
      pagination: { ...s.pagination, limit, page: 1 }
    }));
    
    await volunteers.loadVolunteers();
  },

  /**
   * Clear error state
   */
  clearError(): void {
    volunteersStore.update(s => ({ ...s, error: null }));
  },

  /**
   * Clear selected volunteer
   */
  clearSelection(): void {
    volunteersStore.update(s => ({ ...s, selectedVolunteer: null }));
  },

  /**
   * Reset store to initial state
   */
  reset(): void {
    volunteersStore.set(initialState);
  }
};

// Derived stores for easier access to computed values
export const isVolunteersLoading = derived(
  volunteersStore, 
  $volunteers => $volunteers.isLoading || $volunteers.isCreating || $volunteers.isUpdating || $volunteers.isDeleting
);

export const hasVolunteerError = derived(
  volunteersStore,
  $volunteers => !!$volunteers.error
);

export const volunteersPagination = derived(
  volunteersStore,
  $volunteers => $volunteers.pagination
);

export const volunteersFiltersActive = derived(
  volunteersStore,
  $volunteers => Object.keys($volunteers.filters).length > 0 || !!$volunteers.searchQuery
);
