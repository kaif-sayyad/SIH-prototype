/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./lib/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        navy: {
          DEFAULT: '#14305c',
          dark: '#0d2146',
          light: '#1d4079',
        },
        saffron: {
          DEFAULT: '#e8801a',
          light: '#fff6e6',
        },
        portalGreen: '#1e7a46',
        portalBg: '#f3f5f8',
        portalCard: '#ffffff',
        portalInk: '#1c2430',
        portalMute: '#5a6573',
        portalLine: '#cfd6df',
      },
    },
  },
  plugins: [],
}
