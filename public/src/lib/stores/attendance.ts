import { writable, derived, get } from 'svelte/store';
import { AttendanceApi, type AttendanceRecord, type AttendanceSearchParams, type AttendanceFilters, type MemberAttendanceStats, type EventAttendanceStats, type BulkAttendanceData, type AttendanceRecordData } from '../api/attendance.js';

interface AttendanceState {
  records: AttendanceRecord[];
  currentRecord: AttendanceRecord | null;
  totalCount: number;
  totalPages: number;
  currentPage: number;
  isLoading: boolean;
  error: string | null;
  searchParams: AttendanceSearchParams & AttendanceFilters;
  selectedRecords: Set<number>;
  bulkActionInProgress: boolean;
}

// Initial state
const initialState: AttendanceState = {
  records: [],
  currentRecord: null,
  totalCount: 0,
  totalPages: 0,
  currentPage: 1,
  isLoading: false,
  error: null,
  searchParams: {
    page: 1,
    limit: 10,
    sortBy: 'attendance_date',
    sortOrder: 'desc'
  },
  selectedRecords: new Set(),
  bulkActionInProgress: false
};

// Main store
export const attendanceStore = writable<AttendanceState>(initialState);

// Derived stores
export const isLoadingAttendance = derived(attendanceStore, $store => $store.isLoading);
export const attendanceError = derived(attendanceStore, $store => $store.error);
export const attendanceRecords = derived(attendanceStore, $store => $store.records);
export const currentAttendanceRecord = derived(attendanceStore, $store => $store.currentRecord);
export const selectedAttendanceRecords = derived(attendanceStore, $store => $store.selectedRecords);
export const hasSelectedRecords = derived(attendanceStore, $store => $store.selectedRecords.size > 0);
export const attendancePagination = derived(attendanceStore, $store => ({
  currentPage: $store.currentPage,
  totalPages: $store.totalPages,
  totalCount: $store.totalCount,
  limit: $store.searchParams.limit || 10
}));

// Store for member attendance stats
export const memberAttendanceStats = writable<Map<number, MemberAttendanceStats>>(new Map());

// Store for event attendance stats  
export const eventAttendanceStats = writable<Map<number, EventAttendanceStats>>(new Map());

// Helper functions
function updateStore(updates: Partial<AttendanceState>) {
  attendanceStore.update(state => ({ ...state, ...updates }));
}

function setLoading(loading: boolean) {
  updateStore({ isLoading: loading, error: null });
}

function setError(error: string) {
  updateStore({ isLoading: false, error });
}

// Actions
export const attendanceActions = {
  /**
   * Load attendance records with pagination and filters
   */
  async loadAttendanceRecords(params?: Partial<AttendanceSearchParams & AttendanceFilters>) {
    setLoading(true);
    
    try {
      const currentState = get(attendanceStore);
      const searchParams = { ...currentState.searchParams, ...params };
      
      const response = await AttendanceApi.getAttendanceRecords(searchParams);
      
      updateStore({
        records: response.data,
        totalCount: response.pagination.total,
        totalPages: response.pagination.totalPages,
        currentPage: response.pagination.page,
        searchParams,
        isLoading: false,
        error: null
      });
    } catch (error: any) {
      setError(error.message || 'Failed to load attendance records');
    }
  },

  /**
   * Load a single attendance record
   */
  async loadAttendanceRecord(id: number) {
    setLoading(true);
    
    try {
      const record = await AttendanceApi.getAttendanceRecord(id);
      updateStore({
        currentRecord: record,
        isLoading: false,
        error: null
      });
    } catch (error: any) {
      setError(error.message || 'Failed to load attendance record');
    }
  },

  /**
   * Create a new attendance record
   */
  async createAttendanceRecord(data: AttendanceRecordData) {
    setLoading(true);
    
    try {
      const newRecord = await AttendanceApi.createAttendanceRecord(data);
      
      attendanceStore.update(state => ({
        ...state,
        records: [newRecord, ...state.records],
        totalCount: state.totalCount + 1,
        isLoading: false,
        error: null
      }));
      
      return newRecord;
    } catch (error: any) {
      setError(error.message || 'Failed to create attendance record');
      throw error;
    }
  },

  /**
   * Create multiple attendance records in bulk
   */
  async createBulkAttendance(data: BulkAttendanceData) {
    updateStore({ bulkActionInProgress: true });
    
    try {
      const newRecords = await AttendanceApi.createBulkAttendance(data);
      
      attendanceStore.update(state => ({
        ...state,
        records: [...newRecords, ...state.records],
        totalCount: state.totalCount + newRecords.length,
        bulkActionInProgress: false,
        error: null
      }));
      
      return newRecords;
    } catch (error: any) {
      updateStore({ 
        bulkActionInProgress: false, 
        error: error.message || 'Failed to create bulk attendance records' 
      });
      throw error;
    }
  },

  /**
   * Update an attendance record
   */
  async updateAttendanceRecord(id: number, data: Partial<AttendanceRecordData>) {
    setLoading(true);
    
    try {
      const updatedRecord = await AttendanceApi.updateAttendanceRecord(id, data);
      
      attendanceStore.update(state => ({
        ...state,
        records: state.records.map(record => 
          record.id === id ? updatedRecord : record
        ),
        currentRecord: state.currentRecord?.id === id ? updatedRecord : state.currentRecord,
        isLoading: false,
        error: null
      }));
      
      return updatedRecord;
    } catch (error: any) {
      setError(error.message || 'Failed to update attendance record');
      throw error;
    }
  },

  /**
   * Delete an attendance record
   */
  async deleteAttendanceRecord(id: number) {
    setLoading(true);
    
    try {
      await AttendanceApi.deleteAttendanceRecord(id);
      
      attendanceStore.update(state => ({
        ...state,
        records: state.records.filter(record => record.id !== id),
        totalCount: state.totalCount - 1,
        currentRecord: state.currentRecord?.id === id ? null : state.currentRecord,
        selectedRecords: new Set([...state.selectedRecords].filter(recordId => recordId !== id)),
        isLoading: false,
        error: null
      }));
    } catch (error: any) {
      setError(error.message || 'Failed to delete attendance record');
      throw error;
    }
  },

  /**
   * Delete multiple attendance records
   */
  async deleteBulkAttendanceRecords(ids: number[]) {
    updateStore({ bulkActionInProgress: true });
    
    try {
      await Promise.all(ids.map(id => AttendanceApi.deleteAttendanceRecord(id)));
      
      attendanceStore.update(state => ({
        ...state,
        records: state.records.filter(record => !ids.includes(record.id)),
        totalCount: state.totalCount - ids.length,
        selectedRecords: new Set(),
        bulkActionInProgress: false,
        error: null
      }));
    } catch (error: any) {
      updateStore({ 
        bulkActionInProgress: false, 
        error: error.message || 'Failed to delete attendance records' 
      });
      throw error;
    }
  },

  /**
   * Load attendance for a specific event
   */
  async loadEventAttendance(eventId: number, params?: Omit<AttendanceSearchParams, 'event_id'>) {
    setLoading(true);
    
    try {
      const records = await AttendanceApi.getEventAttendance(eventId, params);
      updateStore({
        records,
        totalCount: records.length,
        totalPages: 1,
        currentPage: 1,
        isLoading: false,
        error: null
      });
    } catch (error: any) {
      setError(error.message || 'Failed to load event attendance');
    }
  },

  /**
   * Load attendance for a specific member
   */
  async loadMemberAttendance(memberId: number, params?: Omit<AttendanceSearchParams, 'member_id'>) {
    setLoading(true);
    
    try {
      const records = await AttendanceApi.getMemberAttendance(memberId, params);
      updateStore({
        records,
        totalCount: records.length,
        totalPages: 1,
        currentPage: 1,
        isLoading: false,
        error: null
      });
    } catch (error: any) {
      setError(error.message || 'Failed to load member attendance');
    }
  },

  /**
   * Load member attendance statistics
   */
  async loadMemberAttendanceStats(memberId: number, startDate?: string, endDate?: string) {
    try {
      const stats = await AttendanceApi.getMemberAttendanceStats(memberId, startDate, endDate);
      memberAttendanceStats.update(statsMap => {
        const newMap = new Map(statsMap);
        newMap.set(memberId, stats);
        return newMap;
      });
      return stats;
    } catch (error: any) {
      setError(error.message || 'Failed to load member attendance statistics');
      throw error;
    }
  },

  /**
   * Load event attendance statistics
   */
  async loadEventAttendanceStats(eventId: number) {
    try {
      const stats = await AttendanceApi.getEventAttendanceStats(eventId);
      eventAttendanceStats.update(statsMap => {
        const newMap = new Map(statsMap);
        newMap.set(eventId, stats);
        return newMap;
      });
      return stats;
    } catch (error: any) {
      setError(error.message || 'Failed to load event attendance statistics');
      throw error;
    }
  },

  /**
   * Search and filter records
   */
  async searchAttendanceRecords(searchParams: Partial<AttendanceSearchParams & AttendanceFilters>) {
    await this.loadAttendanceRecords({ ...searchParams, page: 1 });
  },

  /**
   * Change page
   */
  async changePage(page: number) {
    const currentState = get(attendanceStore);
    await this.loadAttendanceRecords({ ...currentState.searchParams, page });
  },

  /**
   * Change page size
   */
  async changePageSize(limit: number) {
    const currentState = get(attendanceStore);
    await this.loadAttendanceRecords({ ...currentState.searchParams, limit, page: 1 });
  },

  /**
   * Change sorting
   */
  async changeSorting(sortBy: AttendanceSearchParams['sortBy'], sortOrder: 'asc' | 'desc') {
    const currentState = get(attendanceStore);
    await this.loadAttendanceRecords({ ...currentState.searchParams, sortBy, sortOrder, page: 1 });
  },

  /**
   * Select/deselect record
   */
  toggleRecordSelection(id: number) {
    attendanceStore.update(state => {
      const newSelected = new Set(state.selectedRecords);
      if (newSelected.has(id)) {
        newSelected.delete(id);
      } else {
        newSelected.add(id);
      }
      return { ...state, selectedRecords: newSelected };
    });
  },

  /**
   * Select all records on current page
   */
  selectAllRecords() {
    attendanceStore.update(state => {
      const newSelected = new Set(state.selectedRecords);
      state.records.forEach(record => newSelected.add(record.id));
      return { ...state, selectedRecords: newSelected };
    });
  },

  /**
   * Deselect all records
   */
  deselectAllRecords() {
    updateStore({ selectedRecords: new Set() });
  },

  /**
   * Clear current record
   */
  clearCurrentRecord() {
    updateStore({ currentRecord: null });
  },

  /**
   * Clear error
   */
  clearError() {
    updateStore({ error: null });
  },

  /**
   * Reset store to initial state
   */
  reset() {
    attendanceStore.set(initialState);
    memberAttendanceStats.set(new Map());
    eventAttendanceStats.set(new Map());
  },

  /**
   * Export attendance data
   */
  async exportAttendance(format: 'csv' | 'xlsx' = 'csv', filters?: AttendanceFilters) {
    try {
      const blob = await AttendanceApi.exportAttendance(format, filters);
      
      // Create download link
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `attendance-records.${format}`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch (error: any) {
      setError(error.message || 'Failed to export attendance data');
      throw error;
    }
  },

  /**
   * Check if member attended specific event
   */
  async checkMemberEventAttendance(memberId: number, eventId: number) {
    try {
      return await AttendanceApi.checkMemberEventAttendance(memberId, eventId);
    } catch (error: any) {
      console.error('Failed to check member event attendance:', error);
      return null;
    }
  }
};

// Auto-refresh functionality
let autoRefreshInterval: number | null = null;

export function startAutoRefresh(intervalMs: number = 30000) {
  if (autoRefreshInterval) {
    clearInterval(autoRefreshInterval);
  }
  
  autoRefreshInterval = setInterval(() => {
    const currentState = get(attendanceStore);
    if (!currentState.isLoading && !currentState.bulkActionInProgress) {
      attendanceActions.loadAttendanceRecords(currentState.searchParams);
    }
  }, intervalMs);
}

export function stopAutoRefresh() {
  if (autoRefreshInterval) {
    clearInterval(autoRefreshInterval);
    autoRefreshInterval = null;
  }
}
