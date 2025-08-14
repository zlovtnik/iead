import { writable, derived, get } from 'svelte/store';
import { EventsApi, type Event, type EventFormData, type EventSearchParams, type EventFilters, type AttendanceRecord, type VolunteerAssignment, type EventStats } from '../api/events.js';
import { ApiException } from '../api/types.js';

export interface EventsState {
  events: Event[];
  selectedEvent: Event | null;
  isLoading: boolean;
  isCreating: boolean;
  isUpdating: boolean;
  isDeleting: boolean;
  error: string | null;
  searchQuery: string;
  filters: EventFilters;
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
  sortBy: 'title' | 'start_date' | 'created_at';
  sortOrder: 'asc' | 'desc';
  // Calendar-specific state
  calendarView: 'month' | 'week' | 'day';
  currentDate: string; // ISO date string
  // Attendance and volunteers
  eventAttendance: Record<number, AttendanceRecord[]>;
  eventVolunteers: Record<number, VolunteerAssignment[]>;
  eventStats: Record<number, EventStats>;
}

const initialState: EventsState = {
  events: [],
  selectedEvent: null,
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
  sortOrder: 'asc',
  calendarView: 'month',
  currentDate: new Date().toISOString().split('T')[0],
  eventAttendance: {},
  eventVolunteers: {},
  eventStats: {}
};

// Create the writable store
const eventsStore = writable<EventsState>(initialState);

/**
 * Events store with actions for CRUD operations and calendar management
 */
export const events = {
  // Subscribe to the store
  subscribe: eventsStore.subscribe,

  /**
   * Load events with current search, filter, and pagination settings
   */
  async loadEvents(): Promise<void> {
    const state = get(eventsStore);
    
    eventsStore.update(s => ({ ...s, isLoading: true, error: null }));

    try {
      const params: EventSearchParams & EventFilters = {
        query: state.searchQuery || undefined,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        page: state.pagination.page,
        limit: state.pagination.limit,
        ...state.filters
      };

      const response = await EventsApi.getEvents(params);
      
      eventsStore.update(s => ({
        ...s,
        events: response.data,
        pagination: response.pagination,
        isLoading: false,
        error: null
      }));
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to load events. Please try again.';
      
      eventsStore.update(s => ({
        ...s,
        isLoading: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Load events for calendar view within a date range
   */
  async loadEventsForCalendar(startDate: string, endDate: string): Promise<Event[]> {
    eventsStore.update(s => ({ ...s, isLoading: true, error: null }));

    try {
      const events = await EventsApi.getEventsInRange(startDate, endDate);
      
      eventsStore.update(s => ({
        ...s,
        events: events,
        isLoading: false,
        error: null
      }));
      
      return events;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to load calendar events. Please try again.';
      
      eventsStore.update(s => ({
        ...s,
        isLoading: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Load a specific event by ID
   */
  async loadEvent(id: number): Promise<Event> {
    eventsStore.update(s => ({ ...s, isLoading: true, error: null }));

    try {
      const event = await EventsApi.getEvent(id);
      
      eventsStore.update(s => ({
        ...s,
        selectedEvent: event,
        isLoading: false,
        error: null
      }));
      
      return event;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to load event. Please try again.';
      
      eventsStore.update(s => ({
        ...s,
        isLoading: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Create a new event
   */
  async createEvent(eventData: EventFormData): Promise<Event> {
    eventsStore.update(s => ({ ...s, isCreating: true, error: null }));

    try {
      const newEvent = await EventsApi.createEvent(eventData);
      
      eventsStore.update(s => ({
        ...s,
        events: [newEvent, ...s.events],
        isCreating: false,
        error: null
      }));
      
      // Reload to get updated pagination
      await this.loadEvents();
      
      return newEvent;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to create event. Please try again.';
      
      eventsStore.update(s => ({
        ...s,
        isCreating: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Update an existing event
   */
  async updateEvent(id: number, eventData: Partial<EventFormData>): Promise<Event> {
    eventsStore.update(s => ({ ...s, isUpdating: true, error: null }));

    try {
      const updatedEvent = await EventsApi.updateEvent(id, eventData);
      
      eventsStore.update(s => ({
        ...s,
        events: s.events.map(e => e.id === id ? updatedEvent : e),
        selectedEvent: s.selectedEvent?.id === id ? updatedEvent : s.selectedEvent,
        isUpdating: false,
        error: null
      }));
      
      return updatedEvent;
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to update event. Please try again.';
      
      eventsStore.update(s => ({
        ...s,
        isUpdating: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Delete an event
   */
  async deleteEvent(id: number): Promise<void> {
    eventsStore.update(s => ({ ...s, isDeleting: true, error: null }));

    try {
      await EventsApi.deleteEvent(id);
      
      eventsStore.update(s => ({
        ...s,
        events: s.events.filter(e => e.id !== id),
        selectedEvent: s.selectedEvent?.id === id ? null : s.selectedEvent,
        isDeleting: false,
        error: null,
        // Clear related data
        eventAttendance: { ...s.eventAttendance, [id]: undefined },
        eventVolunteers: { ...s.eventVolunteers, [id]: undefined },
        eventStats: { ...s.eventStats, [id]: undefined }
      }));
      
      // Reload to get updated pagination
      await this.loadEvents();
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to delete event. Please try again.';
      
      eventsStore.update(s => ({
        ...s,
        isDeleting: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Search events by query
   */
  async searchEvents(query: string): Promise<Event[]> {
    try {
      return await EventsApi.searchEvents(query);
    } catch (error) {
      console.error('Search failed:', error);
      return [];
    }
  },

  /**
   * Set search query and reload events
   */
  async setSearchQuery(query: string): Promise<void> {
    eventsStore.update(s => ({
      ...s,
      searchQuery: query,
      pagination: { ...s.pagination, page: 1 } // Reset to first page
    }));
    
    await this.loadEvents();
  },

  /**
   * Set filters and reload events
   */
  async setFilters(filters: Partial<EventFilters>): Promise<void> {
    eventsStore.update(s => ({
      ...s,
      filters: { ...s.filters, ...filters },
      pagination: { ...s.pagination, page: 1 } // Reset to first page
    }));
    
    await this.loadEvents();
  },

  /**
   * Clear all filters
   */
  async clearFilters(): Promise<void> {
    eventsStore.update(s => ({
      ...s,
      filters: {},
      searchQuery: '',
      pagination: { ...s.pagination, page: 1 }
    }));
    
    await this.loadEvents();
  },

  /**
   * Set sorting and reload events
   */
  async setSorting(sortBy: 'title' | 'start_date' | 'created_at', sortOrder: 'asc' | 'desc'): Promise<void> {
    eventsStore.update(s => ({
      ...s,
      sortBy,
      sortOrder,
      pagination: { ...s.pagination, page: 1 } // Reset to first page
    }));
    
    await this.loadEvents();
  },

  /**
   * Set page and reload events
   */
  async setPage(page: number): Promise<void> {
    eventsStore.update(s => ({
      ...s,
      pagination: { ...s.pagination, page }
    }));
    
    await this.loadEvents();
  },

  /**
   * Set page size and reload events
   */
  async setPageSize(limit: number): Promise<void> {
    eventsStore.update(s => ({
      ...s,
      pagination: { ...s.pagination, limit, page: 1 } // Reset to first page
    }));
    
    await this.loadEvents();
  },

  /**
   * Set calendar view
   */
  setCalendarView(view: 'month' | 'week' | 'day'): void {
    eventsStore.update(s => ({
      ...s,
      calendarView: view
    }));
  },

  /**
   * Set current calendar date
   */
  setCurrentDate(date: string): void {
    eventsStore.update(s => ({
      ...s,
      currentDate: date
    }));
  },

  /**
   * Load attendance for an event
   */
  async loadEventAttendance(eventId: number): Promise<AttendanceRecord[]> {
    try {
      const attendance = await EventsApi.getEventAttendance(eventId);
      
      eventsStore.update(s => ({
        ...s,
        eventAttendance: {
          ...s.eventAttendance,
          [eventId]: attendance
        }
      }));
      
      return attendance;
    } catch (error) {
      console.error('Failed to load event attendance:', error);
      throw error;
    }
  },

  /**
   * Record bulk attendance for an event
   */
  async recordBulkAttendance(eventId: number, memberIds: number[], attendanceDate?: string): Promise<void> {
    try {
      const records = await EventsApi.recordBulkAttendance(eventId, memberIds, attendanceDate);
      
      eventsStore.update(s => ({
        ...s,
        eventAttendance: {
          ...s.eventAttendance,
          [eventId]: records
        }
      }));
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to record attendance. Please try again.';
      
      eventsStore.update(s => ({
        ...s,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Load volunteers for an event
   */
  async loadEventVolunteers(eventId: number): Promise<VolunteerAssignment[]> {
    try {
      const volunteers = await EventsApi.getEventVolunteers(eventId);
      
      eventsStore.update(s => ({
        ...s,
        eventVolunteers: {
          ...s.eventVolunteers,
          [eventId]: volunteers
        }
      }));
      
      return volunteers;
    } catch (error) {
      console.error('Failed to load event volunteers:', error);
      throw error;
    }
  },

  /**
   * Assign volunteer to event
   */
  async assignVolunteer(assignment: {
    event_id: number;
    member_id: number;
    role: string;
    estimated_hours: number;
  }): Promise<void> {
    try {
      const newAssignment = await EventsApi.assignVolunteer(assignment);
      
      eventsStore.update(s => {
        const existingVolunteers = s.eventVolunteers[assignment.event_id] || [];
        return {
          ...s,
          eventVolunteers: {
            ...s.eventVolunteers,
            [assignment.event_id]: [...existingVolunteers, newAssignment]
          }
        };
      });
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to assign volunteer. Please try again.';
      
      eventsStore.update(s => ({
        ...s,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Load event statistics
   */
  async loadEventStats(eventId: number): Promise<EventStats> {
    try {
      const stats = await EventsApi.getEventStats(eventId);
      
      eventsStore.update(s => ({
        ...s,
        eventStats: {
          ...s.eventStats,
          [eventId]: stats
        }
      }));
      
      return stats;
    } catch (error) {
      console.error('Failed to load event stats:', error);
      throw error;
    }
  },

  /**
   * Select an event
   */
  selectEvent(event: Event | null): void {
    eventsStore.update(s => ({
      ...s,
      selectedEvent: event
    }));
  },

  /**
   * Clear any error state
   */
  clearError(): void {
    eventsStore.update(s => ({
      ...s,
      error: null
    }));
  },

  /**
   * Reset store to initial state
   */
  reset(): void {
    eventsStore.set(initialState);
  },

  /**
   * Export events data
   */
  async exportEvents(format: 'csv' | 'xlsx' = 'csv'): Promise<Blob> {
    const state = get(eventsStore);
    
    try {
      return await EventsApi.exportEvents(format, state.filters);
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Failed to export events. Please try again.';
      
      eventsStore.update(s => ({
        ...s,
        error: errorMessage
      }));
      
      throw error;
    }
  }
};

// Derived stores for common use cases
export const eventsList = derived(eventsStore, $events => $events.events);
export const selectedEvent = derived(eventsStore, $events => $events.selectedEvent);
export const isLoadingEvents = derived(eventsStore, $events => $events.isLoading);
export const isCreatingEvent = derived(eventsStore, $events => $events.isCreating);
export const isUpdatingEvent = derived(eventsStore, $events => $events.isUpdating);
export const isDeletingEvent = derived(eventsStore, $events => $events.isDeleting);
export const eventsError = derived(eventsStore, $events => $events.error);
export const eventsPagination = derived(eventsStore, $events => $events.pagination);
export const eventsSearchQuery = derived(eventsStore, $events => $events.searchQuery);
export const eventsFilters = derived(eventsStore, $events => $events.filters);
export const calendarView = derived(eventsStore, $events => $events.calendarView);
export const currentDate = derived(eventsStore, $events => $events.currentDate);

// Computed derived stores
export const hasEvents = derived(eventsStore, $events => $events.events.length > 0);
export const upcomingEvents = derived(eventsStore, $events => 
  $events.events.filter(event => new Date(event.start_date) > new Date())
);
export const pastEvents = derived(eventsStore, $events => 
  $events.events.filter(event => new Date(event.start_date) <= new Date())
);
export const isAnyEventOperation = derived(
  eventsStore, 
  $events => $events.isLoading || $events.isCreating || $events.isUpdating || $events.isDeleting
);

export default events;
