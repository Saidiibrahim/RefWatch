import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: [
      "integration/onboarding.database.test.ts",
      "integration/greenfieldReadback.database.test.ts",
      "integration/productionMigration0016.database.test.ts",
    ],
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 30_000,
  },
});
