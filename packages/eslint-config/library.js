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
  prettierRecommended,
  { ignores: ["node_modules/", "dist/"] }
);
