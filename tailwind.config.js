/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/views/**/*.{html.erb,html.slim,html.haml}',
    './app/components/**/*.{rb,html.erb}',
    './app/views/**/*.{rb,html.erb}',
    './app/helpers/**/*.rb',
    './app/assets/tailwind/**/*.{css,scss}',
    './app/javascript/**/*.{js,ts}',
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    // se você estiver usando tailwindcss-animate:
    // require('tailwindcss-animate'),
  ],
}
