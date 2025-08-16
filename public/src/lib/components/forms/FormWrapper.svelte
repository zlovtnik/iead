<script lang="ts">
	import { z } from 'zod';
	import { formatZodErrors, formatApiErrors, type FormErrors } from '../../utils/validation.js';
	import Button from '../ui/Button.svelte';

	interface Props<T = any> {
		schema?: z.ZodSchema<T>;
		initialData?: Partial<T>;
		onsubmit: (data: T) => Promise<void> | void;
		submitText?: string;
		submitVariant?: 'primary' | 'secondary' | 'success' | 'warning' | 'error';
		resetOnSubmit?: boolean;
		validateOnChange?: boolean;
		validateOnBlur?: boolean;
		disabled?: boolean;
		class?: string;
		children?: any;
	}

	let {
		schema,
		initialData = {},
		onsubmit,
		submitText = 'Submit',
		submitVariant = 'primary',
		resetOnSubmit = false,
		validateOnChange = false,
		validateOnBlur = true,
		disabled = false,
		class: className = '',
		children
	}: Props = $props();

	// Form state
	let formData = $state({ ...initialData });
	let errors: FormErrors = $state({});
	let isSubmitting = $state(false);
	let hasSubmitted = $state(false);
	let formElement: HTMLFormElement;

	// Validation state
	let isValid = $derived(() => {
		if (!schema) return true;
		try {
			schema.parse(formData);
			return Object.keys(errors).length === 0;
		} catch {
			return false;
		}
	});

	/**
	 * Validates the entire form
	 */
	function validateForm(): FormErrors {
		if (!schema) return {};

		try {
			schema.parse(formData);
			return {};
		} catch (error) {
			if (error instanceof z.ZodError) {
				return formatZodErrors(error);
			}
			return { _general: 'Validation error' };
		}
	}

	/**
	 * Validates a single field
	 */
	function validateField(fieldName: string, value: any): string | null {
		if (!schema) return null;

		try {
			// Create a partial schema for the specific field
			const fieldSchema = schema.shape?.[fieldName];
			if (fieldSchema) {
				fieldSchema.parse(value);
			}
			return null;
		} catch (error) {
			if (error instanceof z.ZodError) {
				return error.errors[0]?.message || 'Invalid value';
			}
			return 'Validation error';
		}
	}

	/**
	 * Handles form submission
	 */
	async function handleSubmit(event: SubmitEvent) {
		event.preventDefault();

		if (isSubmitting || disabled) return;

		hasSubmitted = true;
		isSubmitting = true;

		// Clear previous errors
		errors = {};

		try {
			// Validate form data
			const validationErrors = validateForm();
			if (Object.keys(validationErrors).length > 0) {
				errors = validationErrors;
				return;
			}

			// Submit the form
			await onsubmit(formData);

			// Reset form if requested
			if (resetOnSubmit) {
				formData = { ...initialData };
				hasSubmitted = false;
				errors = {};
			}
		} catch (error: any) {
			// Handle API errors
			const apiErrors = formatApiErrors(error);
			errors = apiErrors;
		} finally {
			isSubmitting = false;
		}
	}

	/**
	 * Handles field value changes
	 */
	function handleFieldChange(fieldName: string, value: any) {
		formData[fieldName] = value;

		// Clear field error when user starts typing
		if (errors[fieldName]) {
			const newErrors = { ...errors };
			delete newErrors[fieldName];
			errors = newErrors;
		}

		// Validate on change if enabled
		if (validateOnChange && hasSubmitted) {
			const fieldError = validateField(fieldName, value);
			if (fieldError) {
				errors = { ...errors, [fieldName]: fieldError };
			}
		}
	}

	/**
	 * Handles field blur events
	 */
	function handleFieldBlur(fieldName: string, value: any) {
		if (validateOnBlur && hasSubmitted) {
			const fieldError = validateField(fieldName, value);
			if (fieldError) {
				errors = { ...errors, [fieldName]: fieldError };
			}
		}
	}

	/**
	 * Resets the form to initial state
	 */
	function resetForm() {
		formData = { ...initialData };
		errors = {};
		hasSubmitted = false;
		isSubmitting = false;
	}

	/**
	 * Sets form data programmatically
	 */
	function setFormData(data: Partial<typeof formData>) {
		formData = { ...formData, ...data };
	}

	/**
	 * Sets form errors programmatically
	 */
	function setFormErrors(newErrors: FormErrors) {
		errors = { ...errors, ...newErrors };
	}

	/**
	 * Gets current form data
	 */
	function getFormData() {
		return { ...formData };
	}

	// Expose methods to parent component
	const formMethods = {
		resetForm,
		setFormData,
		setFormErrors,
		getFormData,
		validateForm,
		isValid: () => isValid,
		isSubmitting: () => isSubmitting
	};

	// Context for child components - use getters to ensure reactivity
	const formContext = {
		get formData() {
			return formData;
		},
		get errors() {
			return errors;
		},
		get isSubmitting() {
			return isSubmitting;
		},
		get hasSubmitted() {
			return hasSubmitted;
		},
		handleFieldChange,
		handleFieldBlur,
		...formMethods
	};
</script>

<form bind:this={formElement} onsubmit={handleSubmit} class={`space-y-4 ${className}`} novalidate>
	<!-- General form error -->
	{#if errors._general}
		<div class="rounded-lg bg-error-50 border border-error-200 p-4" role="alert">
			<div class="flex">
				<div class="flex-shrink-0">
					<svg class="h-5 w-5 text-error-400" viewBox="0 0 20 20" fill="currentColor">
						<path
							fill-rule="evenodd"
							d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
							clip-rule="evenodd"
						/>
					</svg>
				</div>
				<div class="ml-3">
					<p class="text-sm text-error-800">{errors._general}</p>
				</div>
			</div>
		</div>
	{/if}

	<!-- Form fields -->
	<div class="space-y-4">
		{@render children?.(formContext)}
	</div>

	<!-- Submit button -->
	<div class="flex justify-end space-x-3 pt-4">
		<Button
			type="submit"
			variant={submitVariant}
			loading={isSubmitting}
			disabled={disabled || isSubmitting}
		>
			{submitText}
		</Button>
	</div>
</form>
