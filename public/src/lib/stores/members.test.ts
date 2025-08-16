import { describe, it, expect, vi, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import { members, type MembersState } from './members.js';
import { MembersApi, type Member } from '../api/members.js';

// Mock the MembersApi
vi.mock('../api/members.js', () => ({
  MembersApi: {
    getMembers: vi.fn(),
    getMember: vi.fn(),
    createMember: vi.fn(),
    updateMember: vi.fn(),
    deleteMember: vi.fn(),
    searchMembers: vi.fn(),
    getMemberStats: vi.fn(),
    exportMembers: vi.fn()
  }
}));

const mockMembersApi = vi.mocked(MembersApi);

describe('Members Store', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    members.reset();
    members.clearError(); // Also clear any lingering errors
  });

  const mockMember: Member = {
    id: 1,
    name: 'John Doe',
    email: 'john@example.com',
    phone: '+1234567890',
    salary: 50000,
    created_at: '2024-01-01T00:00:00Z'
  };

  const mockMembersResponse = {
    data: [mockMember],
    pagination: {
      page: 1,
      limit: 20,
      total: 1,
      totalPages: 1
    }
  };

  describe('loadMembers', () => {
    it('should load members successfully', async () => {
      mockMembersApi.getMembers.mockResolvedValue(mockMembersResponse);

      await members.loadMembers();

      const state = get(members);
      expect(state.members).toEqual([mockMember]);
      expect(state.pagination).toEqual(mockMembersResponse.pagination);
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
    });

    it('should handle loading errors', async () => {
      const error = new Error('Failed to load members');
      mockMembersApi.getMembers.mockRejectedValue(error);

      await expect(members.loadMembers()).rejects.toThrow();

      const state = get(members);
      expect(state.isLoading).toBe(false);
      expect(state.error).toBe('Failed to load members. Please try again.');
    });

    it('should set loading state during request', async () => {
      let resolvePromise: (value: any) => void;
      const promise = new Promise(resolve => {
        resolvePromise = resolve;
      });
      mockMembersApi.getMembers.mockReturnValue(promise);

      const loadPromise = members.loadMembers();
      
      // Check loading state
      const loadingState = get(members);
      expect(loadingState.isLoading).toBe(true);

      // Resolve the promise
      resolvePromise!(mockMembersResponse);
      await loadPromise;

      // Check final state
      const finalState = get(members);
      expect(finalState.isLoading).toBe(false);
    });
  });

  describe('createMember', () => {
    it('should create member successfully', async () => {
      mockMembersApi.createMember.mockResolvedValue(mockMember);
      mockMembersApi.getMembers.mockResolvedValue(mockMembersResponse);

      const memberData = {
        name: 'John Doe',
        email: 'john@example.com',
        phone: '+1234567890',
        salary: 50000
      };

      const result = await members.createMember(memberData);

      expect(result).toEqual(mockMember);
      expect(mockMembersApi.createMember).toHaveBeenCalledWith(memberData);
      
      const state = get(members);
      expect(state.isCreating).toBe(false);
      expect(state.error).toBeNull();
    });

    it('should handle creation errors', async () => {
      const error = new Error('Failed to create member');
      mockMembersApi.createMember.mockRejectedValue(error);

      const memberData = {
        name: 'John Doe',
        email: 'john@example.com'
      };

      await expect(members.createMember(memberData)).rejects.toThrow();

      const state = get(members);
      expect(state.isCreating).toBe(false);
      expect(state.error).toBe('Failed to create member. Please try again.');
    });
  });

  describe('updateMember', () => {
    it('should update member successfully', async () => {
      const updatedMember = { ...mockMember, name: 'Jane Doe' };
      mockMembersApi.updateMember.mockResolvedValue(updatedMember);

      // Set initial state with the member
      members.selectMember(mockMember);
      const initialState = get(members);
      initialState.members = [mockMember];

      const updateData = { name: 'Jane Doe' };
      const result = await members.updateMember(1, updateData);

      expect(result).toEqual(updatedMember);
      expect(mockMembersApi.updateMember).toHaveBeenCalledWith(1, updateData);

      const state = get(members);
      expect(state.isUpdating).toBe(false);
      expect(state.error).toBeNull();
    });
  });

  describe('deleteMember', () => {
    it('should delete member successfully', async () => {
      mockMembersApi.deleteMember.mockResolvedValue(undefined);
      mockMembersApi.getMembers.mockResolvedValue({
        data: [],
        pagination: { page: 1, limit: 20, total: 0, totalPages: 0 }
      });

      // Set initial state with the member
      const initialState = get(members);
      initialState.members = [mockMember];

      await members.deleteMember(1);

      expect(mockMembersApi.deleteMember).toHaveBeenCalledWith(1);

      const state = get(members);
      expect(state.isDeleting).toBe(false);
      expect(state.error).toBeNull();
    });
  });

  describe('search and filtering', () => {
    it('should set search query and reload', async () => {
      mockMembersApi.getMembers.mockResolvedValue(mockMembersResponse);

      await members.setSearchQuery('John');

      const state = get(members);
      expect(state.searchQuery).toBe('John');
      expect(state.pagination.page).toBe(1); // Should reset to first page
      expect(mockMembersApi.getMembers).toHaveBeenCalledWith(
        expect.objectContaining({ query: 'John' })
      );
    });

    it('should set filters and reload', async () => {
      mockMembersApi.getMembers.mockResolvedValue(mockMembersResponse);

      const filters = { hasEmail: true, minSalary: 30000 };
      await members.setFilters(filters);

      const state = get(members);
      expect(state.filters).toEqual(filters);
      expect(state.pagination.page).toBe(1); // Should reset to first page
      expect(mockMembersApi.getMembers).toHaveBeenCalledWith(
        expect.objectContaining(filters)
      );
    });

    it('should clear filters', async () => {
      mockMembersApi.getMembers.mockResolvedValue(mockMembersResponse);

      // Set some initial filters and search
      await members.setFilters({ hasEmail: true });
      await members.setSearchQuery('test');

      // Clear filters
      await members.clearFilters();

      const state = get(members);
      expect(state.filters).toEqual({});
      expect(state.searchQuery).toBe('');
      expect(state.pagination.page).toBe(1);
    });

    it('should set sorting and reload', async () => {
      mockMembersApi.getMembers.mockResolvedValue(mockMembersResponse);

      await members.setSorting('email', 'desc');

      const state = get(members);
      expect(state.sortBy).toBe('email');
      expect(state.sortOrder).toBe('desc');
      expect(mockMembersApi.getMembers).toHaveBeenCalledWith(
        expect.objectContaining({ sortBy: 'email', sortOrder: 'desc' })
      );
    });

    it('should set page and reload', async () => {
      // Mock the response to include the updated pagination
      const updatedResponse = {
        ...mockMembersResponse,
        pagination: { ...mockMembersResponse.pagination, page: 2 }
      };
      mockMembersApi.getMembers.mockResolvedValue(updatedResponse);

      await members.setPage(2);

      const state = get(members);
      expect(state.pagination.page).toBe(2);
      expect(mockMembersApi.getMembers).toHaveBeenCalledWith(
        expect.objectContaining({ page: 2 })
      );
    });

    it('should set page size and reload', async () => {
      // Mock the response to include the updated pagination
      const updatedResponse = {
        ...mockMembersResponse,
        pagination: { ...mockMembersResponse.pagination, limit: 10, page: 1 }
      };
      mockMembersApi.getMembers.mockResolvedValue(updatedResponse);

      await members.setPageSize(10);

      const state = get(members);
      expect(state.pagination.limit).toBe(10);
      expect(state.pagination.page).toBe(1); // Should reset to first page
      expect(mockMembersApi.getMembers).toHaveBeenCalledWith(
        expect.objectContaining({ limit: 10, page: 1 })
      );
    });
  });

  describe('member selection', () => {
    it('should select a member', () => {
      members.selectMember(mockMember);

      const state = get(members);
      expect(state.selectedMember).toEqual(mockMember);
    });

    it('should clear selected member', () => {
      members.selectMember(mockMember);
      members.selectMember(null);

      const state = get(members);
      expect(state.selectedMember).toBeNull();
    });
  });

  describe('error handling', () => {
    it('should clear errors', () => {
      // Manually set an error state
      const state = get(members);
      state.error = 'Test error';

      members.clearError();

      const clearedState = get(members);
      expect(clearedState.error).toBeNull();
    });
  });

  describe('utility functions', () => {
    it('should search members', async () => {
      const searchResults = [mockMember];
      mockMembersApi.searchMembers.mockResolvedValue(searchResults);

      const result = await members.searchMembers('John');

      expect(result).toEqual(searchResults);
      expect(mockMembersApi.searchMembers).toHaveBeenCalledWith('John');
    });

    it('should get member stats', async () => {
      const stats = {
        totalDonations: 1000,
        attendanceRate: 85,
        volunteerHours: 20
      };
      mockMembersApi.getMemberStats.mockResolvedValue(stats);

      const result = await members.getMemberStats(1);

      expect(result).toEqual(stats);
      expect(mockMembersApi.getMemberStats).toHaveBeenCalledWith(1);
    });

    it('should export members', async () => {
      const blob = new Blob(['csv data'], { type: 'text/csv' });
      mockMembersApi.exportMembers.mockResolvedValue(blob);

      const result = await members.exportMembers('csv');

      expect(result).toEqual(blob);
      expect(mockMembersApi.exportMembers).toHaveBeenCalledWith('csv', {});
    });
  });

  describe('reset', () => {
    it('should reset selected member and search query', () => {
      // Modify state
      members.selectMember(mockMember);
      
      // Verify state is modified
      let state = get(members);
      expect(state.selectedMember).toEqual(mockMember);

      // Reset
      members.reset();

      // Verify reset worked for the parts we can control
      state = get(members);
      expect(state.selectedMember).toBeNull();
      expect(state.searchQuery).toBe('');
      expect(state.error).toBeNull();
      expect(state.isLoading).toBe(false);
      expect(state.isCreating).toBe(false);
      expect(state.isUpdating).toBe(false);
      expect(state.isDeleting).toBe(false);
    });
  });
});