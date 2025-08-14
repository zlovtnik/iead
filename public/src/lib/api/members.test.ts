import { describe, it, expect, vi, beforeEach } from 'vitest';
import { MembersApi, type Member, type MemberFormData } from './members.js';
import { apiClient } from './client.js';

// Mock the API client
vi.mock('./client.js', () => ({
  apiClient: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn()
  }
}));

const mockApiClient = vi.mocked(apiClient);

describe('MembersApi', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const mockMember: Member = {
    id: 1,
    name: 'John Doe',
    email: 'john@example.com',
    phone: '+1234567890',
    salary: 50000,
    created_at: '2024-01-01T00:00:00Z'
  };

  const mockMemberFormData: MemberFormData = {
    name: 'John Doe',
    email: 'john@example.com',
    phone: '+1234567890',
    salary: 50000
  };

  describe('getMembers', () => {
    it('should fetch members with default parameters', async () => {
      const mockResponse = {
        data: [mockMember],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1
        }
      };

      mockApiClient.get.mockResolvedValue(mockResponse);

      const result = await MembersApi.getMembers();

      expect(mockApiClient.get).toHaveBeenCalledWith('/members');
      expect(result).toEqual(mockResponse);
    });

    it('should fetch members with search parameters', async () => {
      const mockResponse = {
        data: [mockMember],
        pagination: {
          page: 1,
          limit: 10,
          total: 1,
          totalPages: 1
        }
      };

      mockApiClient.get.mockResolvedValue(mockResponse);

      const params = {
        query: 'John',
        sortBy: 'name' as const,
        sortOrder: 'asc' as const,
        page: 1,
        limit: 10
      };

      const result = await MembersApi.getMembers(params);

      expect(mockApiClient.get).toHaveBeenCalledWith('/members?query=John&sortBy=name&sortOrder=asc&page=1&limit=10');
      expect(result).toEqual(mockResponse);
    });

    it('should handle filters correctly', async () => {
      const mockResponse = {
        data: [mockMember],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1
        }
      };

      mockApiClient.get.mockResolvedValue(mockResponse);

      const params = {
        hasEmail: true,
        minSalary: 30000,
        maxSalary: 60000
      };

      const result = await MembersApi.getMembers(params);

      expect(mockApiClient.get).toHaveBeenCalledWith('/members?hasEmail=true&minSalary=30000&maxSalary=60000');
      expect(result).toEqual(mockResponse);
    });
  });

  describe('getMember', () => {
    it('should fetch a single member by ID', async () => {
      mockApiClient.get.mockResolvedValue(mockMember);

      const result = await MembersApi.getMember(1);

      expect(mockApiClient.get).toHaveBeenCalledWith('/members/1');
      expect(result).toEqual(mockMember);
    });
  });

  describe('createMember', () => {
    it('should create a new member', async () => {
      mockApiClient.post.mockResolvedValue(mockMember);

      const result = await MembersApi.createMember(mockMemberFormData);

      expect(mockApiClient.post).toHaveBeenCalledWith('/members', mockMemberFormData);
      expect(result).toEqual(mockMember);
    });
  });

  describe('updateMember', () => {
    it('should update an existing member', async () => {
      const updatedMember = { ...mockMember, name: 'Jane Doe' };
      mockApiClient.put.mockResolvedValue(updatedMember);

      const updateData = { name: 'Jane Doe' };
      const result = await MembersApi.updateMember(1, updateData);

      expect(mockApiClient.put).toHaveBeenCalledWith('/members/1', updateData);
      expect(result).toEqual(updatedMember);
    });
  });

  describe('deleteMember', () => {
    it('should delete a member', async () => {
      mockApiClient.delete.mockResolvedValue(undefined);

      await MembersApi.deleteMember(1);

      expect(mockApiClient.delete).toHaveBeenCalledWith('/members/1');
    });
  });

  describe('searchMembers', () => {
    it('should search members with default limit', async () => {
      const mockResponse = {
        data: [mockMember]
      };

      mockApiClient.get.mockResolvedValue(mockResponse);

      const result = await MembersApi.searchMembers('John');

      expect(mockApiClient.get).toHaveBeenCalledWith('/members/search?query=John&limit=10');
      expect(result).toEqual([mockMember]);
    });

    it('should search members with custom limit', async () => {
      const mockResponse = {
        data: [mockMember]
      };

      mockApiClient.get.mockResolvedValue(mockResponse);

      const result = await MembersApi.searchMembers('John', 5);

      expect(mockApiClient.get).toHaveBeenCalledWith('/members/search?query=John&limit=5');
      expect(result).toEqual([mockMember]);
    });
  });

  describe('getMemberStats', () => {
    it('should fetch member statistics', async () => {
      const mockStats = {
        totalDonations: 1000,
        attendanceRate: 85,
        volunteerHours: 20,
        lastAttendance: '2024-01-15T00:00:00Z',
        lastDonation: '2024-01-10T00:00:00Z'
      };

      mockApiClient.get.mockResolvedValue(mockStats);

      const result = await MembersApi.getMemberStats(1);

      expect(mockApiClient.get).toHaveBeenCalledWith('/members/1/stats');
      expect(result).toEqual(mockStats);
    });
  });

  describe('getUpcomingBirthdays', () => {
    it('should fetch upcoming birthdays with default days', async () => {
      const mockResponse = {
        data: [mockMember]
      };

      mockApiClient.get.mockResolvedValue(mockResponse);

      const result = await MembersApi.getUpcomingBirthdays();

      expect(mockApiClient.get).toHaveBeenCalledWith('/members/birthdays?days=30');
      expect(result).toEqual([mockMember]);
    });

    it('should fetch upcoming birthdays with custom days', async () => {
      const mockResponse = {
        data: [mockMember]
      };

      mockApiClient.get.mockResolvedValue(mockResponse);

      const result = await MembersApi.getUpcomingBirthdays(7);

      expect(mockApiClient.get).toHaveBeenCalledWith('/members/birthdays?days=7');
      expect(result).toEqual([mockMember]);
    });
  });

  describe('exportMembers', () => {
    it('should export members with default format', async () => {
      const mockBlob = new Blob(['csv data'], { type: 'text/csv' });
      mockApiClient.get.mockResolvedValue(mockBlob);

      const result = await MembersApi.exportMembers();

      expect(mockApiClient.get).toHaveBeenCalledWith('/members/export?format=csv', {
        responseType: 'blob'
      });
      expect(result).toEqual(mockBlob);
    });

    it('should export members with xlsx format and filters', async () => {
      const mockBlob = new Blob(['xlsx data'], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
      mockApiClient.get.mockResolvedValue(mockBlob);

      const filters = { hasEmail: true, minSalary: 30000 };
      const result = await MembersApi.exportMembers('xlsx', filters);

      expect(mockApiClient.get).toHaveBeenCalledWith('/members/export?format=xlsx&hasEmail=true&minSalary=30000', {
        responseType: 'blob'
      });
      expect(result).toEqual(mockBlob);
    });
  });
});