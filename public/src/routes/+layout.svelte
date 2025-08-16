<script lang="ts">
	import '../app.css';
	import favicon from '$lib/assets/favicon.svg';
	import { onMount } from 'svelte';
	import { auth } from '$lib/stores/auth.js';
	import ToastContainer from '$lib/components/ui/ToastContainer.svelte';

	let { children } = $props();

	// Initialize auth store when the app loads
	onMount(() => {
		auth.init();
	});
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
	<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
</svelte:head>

<div class="app-layout">
	<header class="fancy-header">
		<div class="header-content">
			<h1 class="church-title">🕊️ Blessed Church Community</h1>
			<nav class="main-nav">
				<a href="/" class="nav-link">Home</a>
				<a href="/dashboard" class="nav-link">Dashboard</a>
				<a href="/members" class="nav-link">Members</a>
				<a href="/events" class="nav-link">Events</a>
				<a href="/reports" class="nav-link">Reports</a>
			</nav>
		</div>
	</header>
	
	<main class="main-content">
		{@render children?.()}
	</main>
	
	<footer class="fancy-footer">
		<div class="footer-content">
			<p class="footer-text">&copy; 2025 Blessed Church Community. Walking in faith, growing in grace.</p>
		</div>
	</footer>
</div>

<!-- Global toast container -->
<ToastContainer />

<style>
	:global(.app-layout) {
		min-height: 100vh;
		display: flex;
		flex-direction: column;
		background-color: var(--background);
	}

	.fancy-header {
		background: var(--gradient-divine);
		color: var(--text-color);
		padding: 1.5rem 0;
		box-shadow: var(--shadow-blessed);
		position: relative;
		overflow: hidden;
		border-bottom: 3px solid var(--holy-gold);
	}

	.fancy-header::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: radial-gradient(circle at 20% 50%, rgba(212, 175, 55, 0.15) 0%, transparent 50%),
		            radial-gradient(circle at 80% 20%, rgba(129, 199, 132, 0.15) 0%, transparent 50%);
		pointer-events: none;
	}

	.header-content {
		max-width: 1200px;
		margin: 0 auto;
		padding: 0 2rem;
		position: relative;
		z-index: 1;
		text-align: center;
	}

	.church-title {
		margin: 0 0 1rem 0;
		font-family: var(--font-family);
		font-size: clamp(1.8rem, 4vw, 3rem);
		font-weight: 600;
		color: var(--background-light);
		letter-spacing: 1px;
		text-transform: capitalize;
	}

	.main-nav {
		display: flex;
		justify-content: center;
		gap: 2rem;
		flex-wrap: wrap;
	}

	.nav-link {
		color: var(--background-light);
		text-decoration: none;
		font-family: var(--font-family);
		font-size: 1rem;
		font-weight: 500;
		padding: 0.5rem 1rem;
		border-radius: 20px;
		transition: all 0.3s ease;
		position: relative;
		text-transform: capitalize;
		letter-spacing: 0.3px;
		border: 1px solid rgba(255, 255, 255, 0.3);
	}

	.nav-link::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: linear-gradient(45deg, var(--holy-gold), rgba(212, 175, 55, 0.8));
		border-radius: 20px;
		opacity: 0;
		transition: opacity 0.3s ease;
		z-index: -1;
	}

	.nav-link:hover {
		color: var(--primary-dark);
		transform: translateY(-1px);
		box-shadow: var(--shadow-soft);
	}

	.nav-link:hover::before {
		opacity: 1;
	}

	.main-content {
		flex: 1;
		padding: 3rem 2rem;
		max-width: 1200px;
		margin: 0 auto;
		width: 100%;
		box-sizing: border-box;
	}

	.fancy-footer {
		background: var(--gradient-divine);
		color: var(--background-light);
		padding: 2rem 0;
		margin-top: auto;
		box-shadow: var(--shadow-blessed);
		border-top: 3px solid var(--holy-gold);
	}

	.footer-content {
		max-width: 1200px;
		margin: 0 auto;
		padding: 0 2rem;
		text-align: center;
	}

	.footer-text {
		margin: 0;
		font-family: var(--font-family);
		font-size: 1rem;
		font-style: italic;
		color: var(--background-light);
	}

	@media (max-width: 768px) {
		.main-nav {
			gap: 1rem;
		}
		
		.nav-link {
			font-size: 1rem;
			padding: 0.4rem 0.8rem;
		}
		
		.main-content {
			padding: 2rem 1rem;
		}
	}
</style>
