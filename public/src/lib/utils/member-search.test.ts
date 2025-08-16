import { describe, it, expect } from 'vitest';
import {
  filterMembersByQuery,
  applyMemberFilters,
  sortMembers,
  highlightSearchTerm,
  getMemberDisplayName,
  formatMemberContact,
  memberMatchesSearch,
  getMemberInitials,
  formatSalary,
  groupMembersByLetter,
  createSearchSuggestions,
  createMemberSearchParams
} from './member-search.js';
import type { Member, MemberFilters } from '../api/members.js';

describe('Member Search Utilities', () => {
  const mockMembers: Member[] = [
    {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      phone: '+1234567890',
      salary: 50000,
      created_at: '2024-01-01T00:00:00Z'
    },
    {
      id: 2,
      name: 'Jane Smith',
      email: 'jane@example.com',
      phone: undefined,
      salary: undefined,
      created_at: '2024-01-15T00:00:00Z'
    },
    {
      id: 3,
      name: 'Bob Johnson',
      email: 'bob@example.com',
      phone: '+0987654321',
      salary: 75000,
      created_at: '2024-02-01T00:00:00Z'
    }
  ];

  describe('filterMembersByQuery', () => {
    it('should return all members when query is empty', () => {
      const result = filterMembersByQuery(mockMembers, '');
      expect(result).toEqual(mockMembers);
    });

    it('should filter members by name', () => {
      const result = filterMembersByQuery(mockMembers, 'John');
      expect(result).toHaveLength(2);
      expect(result.map(m => m.name)).toEqual(['John Doe', 'Bob Johnson']);
    });

    it('should filter members by email', () => {
      const result = filterMembersByQuery(mockMembers, 'jane@');
      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('Jane Smith');
    });

    it('should filter members by phone', () => {
      const result = filterMembersByQuery(mockMembers, '+123');
      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('John Doe');
    });

    it('should be case insensitive', () => {
      const result = filterMembersByQuery(mockMembers, 'JOHN');
      expect(result).toHaveLength(2);
    });
  });

  describe('applyMemberFilters', () => {
    it('should filter by hasEmail', () => {
      const filters: MemberFilters = { hasEmail: true };
      const result = applyMemberFilters(mockMembers, filters);
      expect(result).toHaveLength(3); // All have email
    });

    it('should filter by hasPhone', () => {
      const filters: MemberFilters = { hasPhone: true };
      const result = applyMemberFilters(mockMembers, filters);
      expect(result).toHaveLength(2);
      expect(result.map(m => m.name)).toEqual(['John Doe', 'Bob Johnson']);
    });

    it('should filter by hasSalary', () => {
      const filters: MemberFilters = { hasSalary: true };
      const result = applyMemberFilters(mockMembers, filters);
      expect(result).toHaveLength(2);
      expect(result.map(m => m.name)).toEqual(['John Doe', 'Bob Johnson']);
    });

    it('should filter by salary range', () => {
      const filters: MemberFilters = { minSalary: 60000, maxSalary: 80000 };
      const result = applyMemberFilters(mockMembers, filters);
      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('Bob Johnson');
    });

    it('should filter by date range', () => {
      const filters: MemberFilters = { 
        createdAfter: '2024-01-10T00:00:00Z',
        createdBefore: '2024-01-20T00:00:00Z'
      };
      const result = applyMemberFilters(mockMembers, filters);
      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('Jane Smith');
    });

    it('should apply multiple filters', () => {
      const filters: MemberFilters = { 
        hasPhone: true,
        minSalary: 40000
      };
      const result = applyMemberFilters(mockMembers, filters);
      expect(result).toHaveLength(2);
      expect(result.map(m => m.name)).toEqual(['John Doe', 'Bob Johnson']);
    });
  });

  describe('sortMembers', () => {
    it('should sort by name ascending', () => {
      const result = sortMembers(mockMembers, 'name', 'asc');
      expect(result.map(m => m.name)).toEqual(['Bob Johnson', 'Jane Smith', 'John Doe']);
    });

    it('should sort by name descending', () => {
      const result = sortMembers(mockMembers, 'name', 'desc');
      expect(result.map(m => m.name)).toEqual(['John Doe', 'Jane Smith', 'Bob Johnson']);
    });

    it('should sort by email ascending', () => {
      const result = sortMembers(mockMembers, 'email', 'asc');
      expect(result.map(m => m.email)).toEqual(['bob@example.com', 'jane@example.com', 'john@example.com']);
    });

    it('should sort by created_at descending', () => {
      const result = sortMembers(mockMembers, 'created_at', 'desc');
      expect(result.map(m => m.name)).toEqual(['Bob Johnson', 'Jane Smith', 'John Doe']);
    });

    it('should not mutate original array', () => {
      const original = [...mockMembers];
      sortMembers(mockMembers, 'name', 'asc');
      expect(mockMembers).toEqual(original);
    });
  });

  describe('highlightSearchTerm', () => {
    it('should highlight search term', () => {
      const result = highlightSearchTerm('John Doe', 'John');
      expect(result).toBe('<mark>John</mark> Doe');
    });

    it('should be case insensitive', () => {
      const result = highlightSearchTerm('John Doe', 'john');
      expect(result).toBe('<mark>John</mark> Doe');
    });

    it('should return original text when no search term', () => {
      const result = highlightSearchTerm('John Doe', '');
      expect(result).toBe('John Doe');
    });

    it('should escape regex characters', () => {
      const result = highlightSearchTerm('test@example.com', '@');
      expect(result).toBe('test<mark>@</mark>example.com');
    });
  });

  describe('getMemberDisplayName', () => {
    it('should return name when available', () => {
      const result = getMemberDisplayName(mockMembers[0]);
      expect(result).toBe('John Doe');
    });

    it('should return email when name is empty', () => {
      const member = { ...mockMembers[0], name: '' };
      const result = getMemberDisplayName(member);
      expect(result).toBe('john@example.com');
    });

    it('should return fallback when both name and email are empty', () => {
      const member = { ...mockMembers[0], name: '', email: '' };
      const result = getMemberDisplayName(member);
      expect(result).toBe('Unknown Member');
    });
  });

  describe('formatMemberContact', () => {
    it('should format email and phone', () => {
      const result = formatMemberContact(mockMembers[0]);
      expect(result).toBe('john@example.com • +1234567890');
    });

    it('should format email only', () => {
      const result = formatMemberContact(mockMembers[1]);
      expect(result).toBe('jane@example.com');
    });

    it('should handle empty contact info', () => {
      const member = { ...mockMembers[0], email: '', phone: undefined };
      const result = formatMemberContact(member);
      expect(result).toBe('');
    });
  });

  describe('memberMatchesSearch', () => {
    it('should match by name', () => {
      const result = memberMatchesSearch(mockMembers[0], 'John');
      expect(result).toBe(true);
    });

    it('should match by email', () => {
      const result = memberMatchesSearch(mockMembers[0], 'john@');
      expect(result).toBe(true);
    });

    it('should match by phone', () => {
      const result = memberMatchesSearch(mockMembers[0], '+123');
      expect(result).toBe(true);
    });

    it('should not match when no criteria match', () => {
      const result = memberMatchesSearch(mockMembers[0], 'xyz');
      expect(result).toBe(false);
    });

    it('should return true for empty query', () => {
      const result = memberMatchesSearch(mockMembers[0], '');
      expect(result).toBe(true);
    });
  });

  describe('getMemberInitials', () => {
    it('should return initials for full name', () => {
      const result = getMemberInitials(mockMembers[0]);
      expect(result).toBe('JD');
    });

    it('should return single initial for single name', () => {
      const member = { ...mockMembers[0], name: 'John' };
      const result = getMemberInitials(member);
      expect(result).toBe('J');
    });

    it('should use email when name is empty', () => {
      const member = { ...mockMembers[0], name: '' };
      const result = getMemberInitials(member);
      expect(result).toBe('J');
    });

    it('should return ? when no name or email', () => {
      const member = { ...mockMembers[0], name: '', email: '' };
      const result = getMemberInitials(member);
      expect(result).toBe('?');
    });
  });

  describe('formatSalary', () => {
    it('should format salary as currency', () => {
      const result = formatSalary(50000);
      expect(result).toBe('$50,000');
    });

    it('should handle undefined salary', () => {
      const result = formatSalary(undefined);
      expect(result).toBe('Not specified');
    });

    it('should handle null salary', () => {
      const result = formatSalary(null as any);
      expect(result).toBe('Not specified');
    });
  });

  describe('groupMembersByLetter', () => {
    it('should group members by first letter', () => {
      const result = groupMembersByLetter(mockMembers);
      expect(Object.keys(result).sort()).toEqual(['B', 'J']);
      expect(result['J']).toHaveLength(2);
      expect(result['B']).toHaveLength(1);
    });

    it('should use email first letter when name is empty', () => {
      const members = [{ ...mockMembers[0], name: '' }];
      const result = groupMembersByLetter(members);
      expect(Object.keys(result)).toEqual(['J']); // from john@example.com
    });
  });

  describe('createSearchSuggestions', () => {
    it('should create suggestions based on names', () => {
      const result = createSearchSuggestions(mockMembers, 'Jo');
      expect(result).toContain('John Doe');
      expect(result).toContain('Bob Johnson');
    });

    it('should create suggestions based on emails', () => {
      const result = createSearchSuggestions(mockMembers, 'jane@');
      expect(result).toContain('jane@example.com');
    });

    it('should limit suggestions to 10', () => {
      const manyMembers = Array.from({ length: 20 }, (_, i) => ({
        ...mockMembers[0],
        id: i,
        name: `John ${i}`,
        email: `john${i}@example.com`
      }));
      const result = createSearchSuggestions(manyMembers, 'John');
      expect(result.length).toBeLessThanOrEqual(10);
    });

    it('should return empty array for empty query', () => {
      const result = createSearchSuggestions(mockMembers, '');
      expect(result).toEqual([]);
    });
  });

  describe('createMemberSearchParams', () => {
    it('should create URL params with all parameters', () => {
      const filters: MemberFilters = { hasEmail: true, minSalary: 30000 };
      const params = createMemberSearchParams('John', filters, 'email', 'desc', 2, 10);
      
      expect(params.get('query')).toBe('John');
      expect(params.get('sortBy')).toBe('email');
      expect(params.get('sortOrder')).toBe('desc');
      expect(params.get('page')).toBe('2');
      expect(params.get('limit')).toBe('10');
      expect(params.get('hasEmail')).toBe('true');
      expect(params.get('minSalary')).toBe('30000');
    });

    it('should omit default values', () => {
      const params = createMemberSearchParams('', {}, 'name', 'asc', 1, 20);
      
      expect(params.get('query')).toBeNull();
      expect(params.get('sortBy')).toBeNull();
      expect(params.get('sortOrder')).toBeNull();
      expect(params.get('page')).toBeNull();
      expect(params.get('limit')).toBeNull();
    });

    it('should handle empty filters', () => {
      const params = createMemberSearchParams('test', {}, 'name', 'asc', 1, 20);
      
      expect(params.get('query')).toBe('test');
      expect(params.toString()).toBe('query=test');
    });
  });
});