/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: 'class',
  content: ['./src/**/*.{html,js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: { DEFAULT: '#00D4AA', dark: '#00B896', light: '#33E0C0' },
        secondary: { DEFAULT: '#6366F1', dark: '#4F46E5', light: '#818CF8' },
        accent: { DEFAULT: '#F59E0B', dark: '#D97706', light: '#FCD34D' },
        tinker: {
          bg: '#0D0D12', 'bg-secondary': '#12121A',
          'bg-tertiary': '#1A1A26', card: '#16161F',
          border: '#1E1E2E', 'text-primary': '#FFFFFF',
          'text-secondary': '#E0E0E0', 'text-muted': '#888888',
        },
        success: '#10B981', warning: '#F59E0B',
        error: '#EF4444', info: '#3B82F6',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
        display: ['Inter Tight', 'system-ui', 'sans-serif'],
      },
      borderRadius: { none: '0', sm: '4px', md: '8px', lg: '12px', xl: '16px', '2xl': '24px', full: '9999px' },
      boxShadow: { sm: '0 1px 2px rgba(0,0,0,0.3)', md: '0 4px 6px rgba(0,0,0,0.4)', lg: '0 10px 15px rgba(0,0,0,0.5)', xl: '0 20px 25px rgba(0,0,0,0.6)', glow: '0 0 20px rgba(0, 212, 170, 0.3)', 'glow-strong': '0 0 40px rgba(0, 212, 170, 0.5)' },
      transitionDuration: { fast: '150ms', normal: '200ms', slow: '300ms' },
    },
  },
  plugins: [],
}
