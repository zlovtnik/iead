// Export all stores from a central location
export { default as auth, user, isAuthenticated, isLoading, authError, isInitialized } from './auth.js';
export type { AuthState } from './auth.js';

export { 
  default as members, 
  membersList, 
  selectedMember, 
  isLoadingMembers, 
  isCreatingMember, 
  isUpdatingMember, 
  isDeletingMember, 
  membersError, 
  membersPagination, 
  membersSearchQuery, 
  membersFilters,
  hasMembers,
  isAnyMemberOperation
} from './members.js';
export type { MembersState } from './members.js';

export {
  default as events,
  eventsList,
  selectedEvent,
  isLoadingEvents,
  isCreatingEvent,
  isUpdatingEvent,
  isDeletingEvent,
  eventsError,
  eventsPagination,
  eventsSearchQuery,
  eventsFilters,
  calendarView,
  currentDate,
  hasEvents,
  upcomingEvents,
  pastEvents,
  isAnyEventOperation
} from './events.js';
export type { EventsState } from './events.js';

export {
  attendanceStore,
  isLoadingAttendance,
  attendanceError,
  attendanceRecords,
  currentAttendanceRecord,
  selectedAttendanceRecords,
  hasSelectedRecords,
  attendancePagination,
  memberAttendanceStats,
  eventAttendanceStats,
  attendanceActions,
  startAutoRefresh,
  stopAutoRefresh
} from './attendance.js';