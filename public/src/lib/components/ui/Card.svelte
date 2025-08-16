<script lang="ts">
  interface Props {
    title?: string;
    content?: string;
    children?: any;
  }

  let { title = '', content = '', children }: Props = $props();
</script>

<div class="fancy-card">
  {#if title}
    <h4 class="card-title">{title}</h4>
  {/if}
  
  {#if content}
    <p class="card-content">{content}</p>
  {/if}
  
  {#if children}
    {@render children()}
  {/if}
</div>

<style>
  .fancy-card {
    background: linear-gradient(135deg, var(--background-light) 0%, var(--secondary-light) 100%);
    border: 2px solid var(--accent);
    padding: 2rem;
    margin: 1rem 0;
    border-radius: 16px;
    box-shadow: var(--shadow-blessed);
    transition: all 0.3s ease;
    position: relative;
    overflow: hidden;
    font-family: 'Inter', sans-serif;
  }

  .fancy-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 4px;
    background: linear-gradient(135deg, var(--holy-gold), var(--accent));
  }

  .fancy-card:hover {
    transform: translateY(-4px);
    box-shadow: var(--shadow-divine);
    border-color: var(--holy-gold);
  }

  .card-title {
    color: var(--primary, #4A5568);
    font-family: 'Inter', sans-serif;
    font-size: 1.4rem;
    font-weight: 600;
    margin: 0 0 1rem 0;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .card-title::before {
    content: '✝';
    color: var(--holy-gold);
    font-size: 0.8em;
  }

  .card-content {
    color: var(--text-color, #2D3748);
    font-family: 'Inter', sans-serif;
    line-height: 1.7;
    margin: 0;
    font-size: 1.1rem;
  }

  :global(.fancy-card h1),
  :global(.fancy-card h2),
  :global(.fancy-card h3),
  :global(.fancy-card h4),
  :global(.fancy-card h5),
  :global(.fancy-card h6) {
    color: var(--primary, #4A5568);
    font-family: 'Inter', sans-serif;
  }

  :global(.fancy-card p) {
    font-family: 'Inter', sans-serif;
    line-height: 1.7;
    color: var(--text-color, #2D3748);
  }

  :global(.fancy-card a) {
    color: var(--accent, #81C784);
    text-decoration: none;
    transition: all 0.3s ease;
  }

  :global(.fancy-card a:hover) {
    color: var(--accent-dark, #66BB6A);
    text-decoration: underline;
  }
</style>
