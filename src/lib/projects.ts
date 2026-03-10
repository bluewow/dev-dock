import fs from "fs";
import path from "path";

// ─── Types ────────────────────────────────────────────────────────────────────

export interface Project {
  id: string;
  name: string;
  path: string;
  color: string;
  createdAt: string;
  updatedAt: string;
}

export interface TaskLog {
  phase: string;
  status: string;
  date: string;
  note: string;
}

export interface TaskEntry {
  slug: string;
  name: string;
  logs: TaskLog[];
  reviews?: string[];
  spec?: string;
  id?: string;
  path?: string;
}

export interface ScannedFile {
  name: string;
  relativePath: string;
  type: "html" | "md" | "json" | "other";
  size: number;
  modifiedAt: string;
}

export interface ScannedTask {
  slug: string;
  files: ScannedFile[];
  hasSpec: boolean;
}

export interface ProjectScanResult {
  projectId: string;
  tasks: ScannedTask[];
  history: TaskEntry[] | null;
}

// ─── Constants ────────────────────────────────────────────────────────────────

const DATA_DIR = path.join(process.cwd(), "data");
const PROJECTS_FILE = path.join(DATA_DIR, "projects.json");

// ─── Helpers ──────────────────────────────────────────────────────────────────

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
  if (!fs.existsSync(PROJECTS_FILE)) {
    fs.writeFileSync(PROJECTS_FILE, "[]", "utf-8");
  }
}

export function readProjects(): Project[] {
  ensureDataDir();
  try {
    const raw = fs.readFileSync(PROJECTS_FILE, "utf-8");
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

export function writeProjects(projects: Project[]) {
  ensureDataDir();
  fs.writeFileSync(PROJECTS_FILE, JSON.stringify(projects, null, 2), "utf-8");
}

export function findProject(id: string): Project | undefined {
  return readProjects().find((p) => p.id === id);
}

export function getFileType(name: string): ScannedFile["type"] {
  const ext = path.extname(name).toLowerCase();
  if (ext === ".html" || ext === ".htm") return "html";
  if (ext === ".md") return "md";
  if (ext === ".json") return "json";
  return "other";
}

export function scanDocsFolder(projectPath: string): { tasks: ScannedTask[]; history: TaskEntry[] | null } {
  const docsDir = path.join(projectPath, "docs");
  let history: TaskEntry[] | null = null;

  // Read history.json if exists
  const historyPath = path.join(docsDir, "history.json");
  if (fs.existsSync(historyPath)) {
    try {
      history = JSON.parse(fs.readFileSync(historyPath, "utf-8"));
    } catch {
      history = null;
    }
  }

  // Scan docs/tasks/ folder
  const tasks: ScannedTask[] = [];
  const tasksDir = path.join(docsDir, "tasks");

  if (fs.existsSync(tasksDir)) {
    const taskFolders = fs.readdirSync(tasksDir, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name)
      .sort();

    for (const folder of taskFolders) {
      const taskPath = path.join(tasksDir, folder);
      const files: ScannedFile[] = [];
      let hasSpec = false;

      const entries = fs.readdirSync(taskPath, { withFileTypes: true })
        .filter((e) => e.isFile());

      for (const entry of entries) {
        const filePath = path.join(taskPath, entry.name);
        const stat = fs.statSync(filePath);
        const fileType = getFileType(entry.name);

        if (entry.name === "spec.md") hasSpec = true;

        files.push({
          name: entry.name,
          relativePath: path.join("docs", "tasks", folder, entry.name).replace(/\\/g, "/"),
          type: fileType,
          size: stat.size,
          modifiedAt: stat.mtime.toISOString(),
        });
      }

      tasks.push({ slug: folder, files, hasSpec });
    }
  }

  // Also scan docs/reviews/ and docs/specs/ for legacy structure
  const reviewsDir = path.join(docsDir, "reviews");
  if (fs.existsSync(reviewsDir) && tasks.length === 0) {
    const files: ScannedFile[] = [];
    const entries = fs.readdirSync(reviewsDir, { withFileTypes: true })
      .filter((e) => e.isFile());

    for (const entry of entries) {
      const filePath = path.join(reviewsDir, entry.name);
      const stat = fs.statSync(filePath);
      files.push({
        name: entry.name,
        relativePath: path.join("docs", "reviews", entry.name).replace(/\\/g, "/"),
        type: getFileType(entry.name),
        size: stat.size,
        modifiedAt: stat.mtime.toISOString(),
      });
    }

    if (files.length > 0) {
      const specsDir = path.join(docsDir, "specs");
      let hasSpec = false;
      if (fs.existsSync(specsDir)) {
        hasSpec = fs.readdirSync(specsDir).some((f) => f.endsWith(".md"));
        const specEntries = fs.readdirSync(specsDir, { withFileTypes: true }).filter((e) => e.isFile());
        for (const entry of specEntries) {
          const filePath = path.join(specsDir, entry.name);
          const stat = fs.statSync(filePath);
          files.push({
            name: entry.name,
            relativePath: path.join("docs", "specs", entry.name).replace(/\\/g, "/"),
            type: getFileType(entry.name),
            size: stat.size,
            modifiedAt: stat.mtime.toISOString(),
          });
        }
      }
      tasks.push({ slug: "legacy", files, hasSpec });
    }
  }

  return { tasks, history };
}

export function isPathSafe(basePath: string, requestedPath: string): boolean {
  const resolved = path.resolve(basePath, requestedPath);
  const docsDir = path.join(basePath, "docs");
  return resolved.startsWith(docsDir);
}
