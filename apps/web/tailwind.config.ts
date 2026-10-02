import type { Config } from "tailwindcss";

export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: { DEFAULT: "#B45309", dark: "#3D1F00", soft: "#FFF1E6" },
        canvas: "#F0F2F5",
        ink: "#1A1A1A",
        line: "#E5E7EB",
      },
      fontFamily: { sans: ["Space Grotesk", "ui-sans-serif", "system-ui"] },
      boxShadow: { soft: "0 10px 30px rgba(17, 24, 39, .08)" },
    },
  },
  plugins: [],
} satisfies Config;
