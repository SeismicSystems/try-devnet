import type { NextConfig } from "next";
import { loadEnvConfig } from "@next/env";
import { resolve } from "node:path";

const cwd = process.cwd();
const repoRoot = cwd.endsWith("packages/frontend") || cwd.endsWith("packages\\frontend")
  ? resolve(cwd, "../..")
  : cwd;

loadEnvConfig(repoRoot);

const nextConfig: NextConfig = {
  /* config options here */
};

export default nextConfig;
