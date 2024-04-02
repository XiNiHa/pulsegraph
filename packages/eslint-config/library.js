import { resolve } from "node:path";
import eslint from "@eslint/js";
import typescript from "typescript-eslint";
import prettierRecommended from "eslint-plugin-prettier/recommended";

const cwd = process.cwd();
const project = resolve(cwd, "tsconfig.json");

export default typescript.config(
  eslint.configs.recommended,
  ...typescript.configs.recommendedTypeChecked,
  {
    files: ["**/*.{ts,tsx}"],
    languageOptions: {
      parserOptions: { project, tsconfigRootDir: cwd },
    },
  },
  {
    files: ["**/*.test.ts"],
    rules: {
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
    },
  },
  prettierRecommended,
  { ignores: ["node_modules/", "dist/"] }
);
