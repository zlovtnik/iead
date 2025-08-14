import { writable } from 'svelte/store';

export interface ToastMessage {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  title?: string;
  message: string;
  duration?: number;
  closable?: boolean;
  show?: boolean;
}

function createToastStore() {
  const { subscribe, update } = writable<ToastMessage[]>([]);

  return {
    subscribe,
    toasts: { subscribe },
    
    add: (toast: Omit<ToastMessage, 'id' | 'show'>) => {
      const id = Math.random().toString(36).substr(2, 9);
      const newToast: ToastMessage = {
        id,
        show: true,
        duration: 5000,
        closable: true,
        ...toast
      };
      
      update(toasts => [...toasts, newToast]);
      
      // Auto-remove after duration if specified
      if (newToast.duration && newToast.duration > 0) {
        setTimeout(() => {
          toastStore.remove(id);
        }, newToast.duration);
      }
      
      return id;
    },
    
    remove: (id: string) => {
      update(toasts => toasts.filter(toast => toast.id !== id));
    },
    
    clear: () => {
      update(() => []);
    },
    
    success: (message: string, title?: string, options?: Partial<ToastMessage>) => {
      return toastStore.add({ type: 'success', message, title, ...options });
    },
    
    error: (message: string, title?: string, options?: Partial<ToastMessage>) => {
      return toastStore.add({ type: 'error', message, title, ...options });
    },
    
    warning: (message: string, title?: string, options?: Partial<ToastMessage>) => {
      return toastStore.add({ type: 'warning', message, title, ...options });
    },
    
    info: (message: string, title?: string, options?: Partial<ToastMessage>) => {
      return toastStore.add({ type: 'info', message, title, ...options });
    }
  };
}

export const toastStore = createToastStore();

// Modal store for managing modal state
function createModalStore() {
  const { subscribe, set, update } = writable<{
    isOpen: boolean;
    component?: any;
    props?: Record<string, any>;
  }>({
    isOpen: false
  });

  return {
    subscribe,
    
    open: (component?: any, props?: Record<string, any>) => {
      set({ isOpen: true, component, props });
    },
    
    close: () => {
      set({ isOpen: false, component: undefined, props: undefined });
    }
  };
}

export const modalStore = createModalStore();

// Loading store for global loading states
function createLoadingStore() {
  const { subscribe, set, update } = writable<{
    isLoading: boolean;
    message?: string;
  }>({
    isLoading: false
  });

  return {
    subscribe,
    
    start: (message?: string) => {
      set({ isLoading: true, message });
    },
    
    stop: () => {
      set({ isLoading: false, message: undefined });
    }
  };
}

export const loadingStore = createLoadingStore();