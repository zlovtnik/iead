import { writable, derived, get } from 'svelte/store';
import { MembersApi, type Member, type MemberFormData, type MemberSearchParams, type MemberFilters } from '../api/members.js';
import { ApiException } from '../api/types.js';

export interface MembersState {
  members: Member[];
  selectedMember: Member | null;
  isLoading: boolean;
  isCreating: boolean;
  isUpdating: boolean;
  isDeleting: boolean;
  error: string | null;
  searchQuery: string;
  filters: MemberFilters;
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
  sortBy: 'name' | 'email' | 'created_at';
  sortOrder: 'asc' | 'desc';
}

const initialState: MembersState = {
  members: [],
  selectedMember: null,
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
  sortBy: 'name',
  sortOrder: 'asc'
};

// Create the writable store
const membersStore = writable<MembersState>(initialState);

/**
 * Members store with actions for CRUD operations and search/filtering
 */
export const members = {
  // Subscribe to the store
  subscribe: membersStore.subscribe,

  /**
   * Load members with current search, filter, and pagination settings
   */
  async loadMembers(): Promise<void> {
    const state = get(membersStore);
    
    membersStore.update(s => ({ ...s, isLoading: true, error: null }));

    try {
      const params: MemberSearchParams & MemberFilters = {
        query: state.searchQuery || undefined,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        page: state.pagination.page,
        limit: state.pagination.limit,
        ...state.filters
      };

      const response = await MembersApi.getMembers(params);
      
      membersStore.update(s => ({
        ...s,
        members: response.data,
        pagination: response.pagination,
        isLoading: false,
        error: null
      }));
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to load members. Please try again.';
      
      membersStore.update(s => ({
        ...s,
        isLoading: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Load a specific member by ID
   */
  async loadMember(id: number): Promise<Member> {
    membersStore.update(s => ({ ...s, isLoading: true, error: null }));

    try {
      const member = await MembersApi.getMember(id);
      
      membersStore.update(s => ({
        ...s,
        selectedMember: member,
        isLoading: false,
        error: null
      }));
      
      return member;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to load member. Please try again.';
      
      membersStore.update(s => ({
        ...s,
        isLoading: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Create a new member
   */
  async createMember(memberData: MemberFormData): Promise<Member> {
    membersStore.update(s => ({ ...s, isCreating: true, error: null }));

    try {
      const newMember = await MembersApi.createMember(memberData);
      
      membersStore.update(s => ({
        ...s,
        members: [newMember, ...s.members],
        isCreating: false,
        error: null
      }));
      
      // Reload to get updated pagination
      await this.loadMembers();
      
      return newMember;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to create member. Please try again.';
      
      membersStore.update(s => ({
        ...s,
        isCreating: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Update an existing member
   */
  async updateMember(id: number, memberData: Partial<MemberFormData>): Promise<Member> {
    membersStore.update(s => ({ ...s, isUpdating: true, error: null }));

    try {
      const updatedMember = await MembersApi.updateMember(id, memberData);
      
      membersStore.update(s => ({
        ...s,
        members: s.members.map(m => m.id === id ? updatedMember : m),
        selectedMember: s.selectedMember?.id === id ? updatedMember : s.selectedMember,
        isUpdating: false,
        error: null
      }));
      
      return updatedMember;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to update member. Please try again.';
      
      membersStore.update(s => ({
        ...s,
        isUpdating: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Delete a member
   */
  async deleteMember(id: number): Promise<void> {
    membersStore.update(s => ({ ...s, isDeleting: true, error: null }));

    try {
      await MembersApi.deleteMember(id);
      
      membersStore.update(s => ({
        ...s,
        members: s.members.filter(m => m.id !== id),
        selectedMember: s.selectedMember?.id === id ? null : s.selectedMember,
        isDeleting: false,
        error: null
      }));
      
      // Reload to get updated pagination
      await this.loadMembers();
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to delete member. Please try again.';
      
      membersStore.update(s => ({
        ...s,
        isDeleting: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Search members by query
   */
  async searchMembers(query: string): Promise<Member[]> {
    try {
      return await MembersApi.searchMembers(query);
    } catch (error) {
      console.error('Search failed:', error);
      return [];
    }
  },

  /**
   * Set search query and reload members
   */
  async setSearchQuery(query: string): Promise<void> {
    membersStore.update(s => ({
      ...s,
      searchQuery: query,
      pagination: { ...s.pagination, page: 1 } // Reset to first page
    }));
    
    await this.loadMembers();
  },

  /**
   * Set filters and reload members
   */
  async setFilters(filters: Partial<MemberFilters>): Promise<void> {
    membersStore.update(s => ({
      ...s,
      filters: { ...s.filters, ...filters },
      pagination: { ...s.pagination, page: 1 } // Reset to first page
    }));
    
    await this.loadMembers();
  },

  /**
   * Clear all filters
   */
  async clearFilters(): Promise<void> {
    membersStore.update(s => ({
      ...s,
      filters: {},
      searchQuery: '',
      pagination: { ...s.pagination, page: 1 }
    }));
    
    await this.loadMembers();
  },

  /**
   * Set sorting and reload members
   */
  async setSorting(sortBy: 'name' | 'email' | 'created_at', sortOrder: 'asc' | 'desc'): Promise<void> {
    membersStore.update(s => ({
      ...s,
      sortBy,
      sortOrder,
      pagination: { ...s.pagination, page: 1 } // Reset to first page
    }));
    
    await this.loadMembers();
  },

  /**
   * Set page and reload members
   */
  async setPage(page: number): Promise<void> {
    membersStore.update(s => ({
      ...s,
      pagination: { ...s.pagination, page }
    }));
    
    await this.loadMembers();
  },

  /**
   * Set page size and reload members
   */
  async setPageSize(limit: number): Promise<void> {
    membersStore.update(s => ({
      ...s,
      pagination: { ...s.pagination, limit, page: 1 } // Reset to first page
    }));
    
    await this.loadMembers();
  },

  /**
   * Select a member
   */
  selectMember(member: Member | null): void {
    membersStore.update(s => ({
      ...s,
      selectedMember: member
    }));
  },

  /**
   * Clear any error state
   */
  clearError(): void {
    membersStore.update(s => ({
      ...s,
      error: null
    }));
  },

  /**
   * Reset store to initial state
   */
  reset(): void {
    membersStore.set(initialState);
  },

  /**
   * Get member statistics
   */
  async getMemberStats(id: number): Promise<any> {
    try {
      return await MembersApi.getMemberStats(id);
    } catch (error) {
      console.error('Failed to load member stats:', error);
      throw error;
    }
  },

  /**
   * Export members data
   */
  async exportMembers(format: 'csv' | 'xlsx' = 'csv'): Promise<Blob> {
    const state = get(membersStore);
    
    try {
      return await MembersApi.exportMembers(format, state.filters);
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to export members. Please try again.';
      
      membersStore.update(s => ({
        ...s,
        error: errorMessage
      }));
      
      throw error;
    }
  }
};

// Derived stores for common use cases
export const membersList = derived(membersStore, $members => $members.members);
export const selectedMember = derived(membersStore, $members => $members.selectedMember);
export const isLoadingMembers = derived(membersStore, $members => $members.isLoading);
export const isCreatingMember = derived(membersStore, $members => $members.isCreating);
export const isUpdatingMember = derived(membersStore, $members => $members.isUpdating);
export const isDeletingMember = derived(membersStore, $members => $members.isDeleting);
export const membersError = derived(membersStore, $members => $members.error);
export const membersPagination = derived(membersStore, $members => $members.pagination);
export const membersSearchQuery = derived(membersStore, $members => $members.searchQuery);
export const membersFilters = derived(membersStore, $members => $members.filters);

// Computed derived stores
export const hasMembers = derived(membersStore, $members => $members.members.length > 0);
export const isAnyMemberOperation = derived(
  membersStore, 
  $members => $members.isLoading || $members.isCreating || $members.isUpdating || $members.isDeleting
);

export default members;