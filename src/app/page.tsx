"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";

// ─── Types ────────────────────────────────────────────────────────────────────

interface Project {
  id: string;
  name: string;
  path: string;
  color: string;
  createdAt: string;
  updatedAt: string;
}

interface TaskLog {
  phase: string;
  status: string;
  date: string;
  note: string;
}

interface TaskEntry {
  slug: string;
  name: string;
  logs: TaskLog[];
}

interface ProjectWithScan extends Project {
  history?: TaskEntry[] | null;
  taskCount?: number;
  completedCount?: number;
  latestActivity?: string;
  latestStatus?: string;
}

// ─── Color Map ────────────────────────────────────────────────────────────────

const COLOR_MAP: Record<string, { dot: string; bg: string; text: string }> = {
  emerald: { dot: "bg-emerald-400", bg: "bg-emerald-50", text: "text-emerald-700" },
  blue: { dot: "bg-blue-400", bg: "bg-blue-50", text: "text-blue-700" },
  purple: { dot: "bg-purple-400", bg: "bg-purple-50", text: "text-purple-700" },
  amber: { dot: "bg-amber-400", bg: "bg-amber-50", text: "text-amber-700" },
  rose: { dot: "bg-rose-400", bg: "bg-rose-50", text: "text-rose-700" },
  slate: { dot: "bg-slate-400", bg: "bg-slate-50", text: "text-slate-700" },
};

const COLORS = ["emerald", "blue", "purple", "amber", "rose", "slate"];

// ─── Sidebar Component ───────────────────────────────────────────────────────

function Sidebar({ collapsed, onToggle }: { collapsed: boolean; onToggle: () => void }) {
  return (
    <aside
      className={`${collapsed ? "w-14" : "w-56"} sidebar-transition bg-white border-r border-slate-200 flex flex-col flex-shrink-0 h-screen sticky top-0`}
    >
      {/* Logo */}
      <div className={`${collapsed ? "px-3" : "px-4"} py-5 border-b border-slate-100`}>
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 bg-primary-600 rounded-lg flex items-center justify-center flex-shrink-0 cursor-pointer" onClick={onToggle}>
            <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} />
            </svg>
          </div>
          {!collapsed && <span className="font-bold text-slate-800">Milestone</span>}
        </div>
      </div>

      {/* Nav */}
      <nav className={`flex-1 ${collapsed ? "px-2" : "px-3"} py-4 space-y-1`}>
        <Link
          href="/"
          className={`flex items-center gap-3 ${collapsed ? "justify-center px-0 py-2.5" : "px-3 py-2.5"} rounded-xl bg-primary-50 text-primary-700 font-medium text-sm`}
        >
          <svg className="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} />
          </svg>
          {!collapsed && <span>대시보드</span>}
        </Link>
      </nav>

      {/* Bottom */}
      <div className={`${collapsed ? "px-2" : "px-3"} py-4 border-t border-slate-100`}>
        <button
          onClick={onToggle}
          className={`flex items-center gap-3 ${collapsed ? "justify-center px-0 py-2.5 w-full" : "px-3 py-2.5"} rounded-xl text-slate-400 hover:bg-slate-50 text-sm transition-colors`}
        >
          <svg className={`w-4 h-4 flex-shrink-0 transition-transform ${collapsed ? "rotate-180" : ""}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path d="M11 19l-7-7 7-7m8 14l-7-7 7-7" strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} />
          </svg>
          {!collapsed && <span>접기</span>}
        </button>
      </div>
    </aside>
  );
}

// ─── Add Project Modal ────────────────────────────────────────────────────────

function AddProjectModal({
  open,
  onClose,
  onCreated,
}: {
  open: boolean;
  onClose: () => void;
  onCreated: (project: Project) => void;
}) {
  const [name, setName] = useState("");
  const [projectPath, setProjectPath] = useState("");
  const [color, setColor] = useState("emerald");
  const [validating, setValidating] = useState(false);
  const [validation, setValidation] = useState<{ valid: boolean; hasDocs: boolean; message: string } | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const handleValidate = useCallback(async () => {
    if (!projectPath.trim()) return;
    setValidating(true);
    setValidation(null);
    try {
      const res = await fetch(`/api/projects/validate/check?path=${encodeURIComponent(projectPath.trim())}`);
      const data = await res.json();
      setValidation(data);
    } catch {
      setValidation({ valid: false, hasDocs: false, message: "검증 요청에 실패했습니다." });
    }
    setValidating(false);
  }, [projectPath]);

  const handleSubmit = useCallback(async () => {
    if (!name.trim() || !projectPath.trim()) return;
    setSubmitting(true);
    setError("");
    try {
      const res = await fetch("/api/projects", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: name.trim(), path: projectPath.trim(), color }),
      });
      if (!res.ok) {
        const data = await res.json();
        setError(data.error || "등록에 실패했습니다.");
        setSubmitting(false);
        return;
      }
      const project = await res.json();
      onCreated(project);
      setName("");
      setProjectPath("");
      setColor("emerald");
      setValidation(null);
      onClose();
    } catch {
      setError("등록 요청에 실패했습니다.");
    }
    setSubmitting(false);
  }, [name, projectPath, color, onClose, onCreated]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center animate-fadeIn">
      <div className="absolute inset-0 bg-black/30 backdrop-blur-sm" onClick={onClose} />
      <div className="relative bg-white rounded-2xl shadow-2xl p-6 mx-4 w-full max-w-md space-y-5 animate-slideUp">
        <div>
          <h3 className="text-lg font-bold text-slate-800">새 프로젝트 등록</h3>
          <p className="text-sm text-slate-500 mt-1">로컬 프로젝트 폴더를 등록하세요</p>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-xs font-bold uppercase text-slate-400 mb-1.5">프로젝트 이름</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="예: My Project"
              className="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none transition-shadow"
            />
          </div>

          <div>
            <label className="block text-xs font-bold uppercase text-slate-400 mb-1.5">로컬 경로</label>
            <div className="flex gap-2">
              <input
                type="text"
                value={projectPath}
                onChange={(e) => { setProjectPath(e.target.value); setValidation(null); }}
                placeholder="예: C:\project\my-project"
                className="flex-1 rounded-xl border border-slate-200 px-3 py-2.5 text-sm font-mono focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none transition-shadow"
              />
              <button
                onClick={handleValidate}
                disabled={validating || !projectPath.trim()}
                className="px-3 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-600 rounded-xl text-sm transition-colors disabled:opacity-50"
              >
                {validating ? "..." : "검증"}
              </button>
            </div>
            {validation && (
              <div className="flex items-center gap-1.5 mt-1.5">
                <span className={`w-2 h-2 rounded-full ${validation.valid ? "bg-emerald-400" : "bg-red-400"}`} />
                <span className={`text-xs ${validation.valid ? "text-emerald-600" : "text-red-600"}`}>{validation.message}</span>
              </div>
            )}
          </div>

          <div>
            <label className="block text-xs font-bold uppercase text-slate-400 mb-1.5">카드 컬러</label>
            <div className="flex gap-2">
              {COLORS.map((c) => (
                <div
                  key={c}
                  onClick={() => setColor(c)}
                  className={`w-8 h-8 rounded-lg ${COLOR_MAP[c].dot} cursor-pointer border-2 transition-all ${
                    color === c ? "border-primary-600 ring-2 ring-primary-200" : "border-transparent hover:border-slate-300"
                  }`}
                />
              ))}
            </div>
          </div>
        </div>

        {error && <p className="text-sm text-red-600">{error}</p>}

        <div className="flex gap-3 justify-end pt-2">
          <button
            onClick={onClose}
            className="px-4 py-2.5 text-sm font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
          >
            취소
          </button>
          <button
            onClick={handleSubmit}
            disabled={submitting || !name.trim() || !projectPath.trim()}
            className="px-4 py-2.5 text-sm font-bold text-white bg-primary-600 hover:bg-primary-700 rounded-xl transition-colors shadow-sm disabled:opacity-50"
          >
            {submitting ? "등록 중..." : "등록"}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Delete Confirm Modal ─────────────────────────────────────────────────────

function DeleteConfirmModal({
  project,
  onClose,
  onConfirm,
}: {
  project: Project | null;
  onClose: () => void;
  onConfirm: () => void;
}) {
  if (!project) return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center animate-fadeIn">
      <div className="absolute inset-0 bg-black/30 backdrop-blur-sm" onClick={onClose} />
      <div className="relative bg-white rounded-2xl shadow-2xl p-6 mx-4 max-w-sm w-full space-y-4 animate-slideUp">
        <h3 className="text-lg font-bold text-slate-800">프로젝트를 삭제할까요?</h3>
        <p className="text-sm text-slate-600">
          <strong>{project.name}</strong> 프로젝트를 목록에서 제거합니다.<br />
          실제 파일은 삭제되지 않습니다.
        </p>
        <div className="flex gap-3 justify-end">
          <button onClick={onClose} className="px-4 py-2 text-sm font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors">취소</button>
          <button onClick={onConfirm} className="px-4 py-2 text-sm font-medium text-white bg-red-500 hover:bg-red-600 rounded-xl transition-colors">삭제</button>
        </div>
      </div>
    </div>
  );
}

// ─── Project Card ─────────────────────────────────────────────────────────────

function ProjectCard({ project, onDelete }: { project: ProjectWithScan; onDelete: (p: Project) => void }) {
  const colors = COLOR_MAP[project.color] || COLOR_MAP.emerald;
  const total = project.taskCount || 0;
  const completed = project.completedCount || 0;
  const pct = total === 0 ? 0 : Math.round((completed / total) * 100);

  const lastStatus = project.latestStatus || "비활성";
  const statusColors: Record<string, { bg: string; text: string }> = {
    "완료": { bg: "bg-emerald-50", text: "text-emerald-700" },
    "승인": { bg: "bg-emerald-50", text: "text-emerald-700" },
    "진행중": { bg: "bg-purple-50", text: "text-purple-700" },
    "기획": { bg: "bg-blue-50", text: "text-blue-700" },
    "반려": { bg: "bg-red-50", text: "text-red-700" },
    "대기": { bg: "bg-amber-50", text: "text-amber-700" },
  };
  const sc = statusColors[lastStatus] || { bg: "bg-slate-50", text: "text-slate-700" };

  return (
    <div className="task-card-animate bg-white rounded-xl border border-slate-200 p-5 hover:border-primary-300 hover:shadow-md transition-all group relative">
      <button
        onClick={(e) => { e.preventDefault(); e.stopPropagation(); onDelete(project); }}
        className="absolute top-3 right-3 p-1 text-slate-300 hover:text-red-500 transition-colors opacity-0 group-hover:opacity-100"
        aria-label="프로젝트 삭제"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
        </svg>
      </button>

      <Link href={`/projects/${project.id}`} className="block">
        <div className="flex items-start justify-between mb-3 pr-6">
          <div className="flex items-center gap-2.5">
            <div className={`w-3 h-3 rounded-full ${colors.dot}`} />
            <h3 className="font-bold text-slate-800 group-hover:text-primary-700 transition-colors">{project.name}</h3>
          </div>
          <span className={`text-xs ${sc.bg} ${sc.text} px-2 py-0.5 rounded-full font-medium`}>{lastStatus}</span>
        </div>

        <p className="text-xs text-slate-400 mb-3 font-mono truncate">{project.path}</p>

        {total > 0 && (
          <div className="mb-3">
            <div className="flex justify-between text-xs mb-1">
              <span className="text-slate-400">진행률</span>
              <span className="font-bold text-primary-600">{completed}/{total}</span>
            </div>
            <div className="h-1.5 bg-slate-100 rounded-full overflow-hidden">
              <div className={`h-full ${colors.dot} rounded-full progress-fill-transition`} style={{ width: `${pct}%` }} />
            </div>
          </div>
        )}

        {project.latestActivity && (
          <div className="pt-3 border-t border-slate-100">
            <div className="flex items-center gap-2 text-xs">
              <span className="w-1.5 h-1.5 rounded-full bg-amber-400 flex-shrink-0" />
              <span className="text-slate-600 truncate">{project.latestActivity}</span>
            </div>
          </div>
        )}
      </Link>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function Dashboard() {
  const [projects, setProjects] = useState<ProjectWithScan[]>([]);
  const [loading, setLoading] = useState(true);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Project | null>(null);

  const fetchProjects = useCallback(async () => {
    try {
      const res = await fetch("/api/projects");
      const data: Project[] = await res.json();

      const enriched: ProjectWithScan[] = await Promise.all(
        data.map(async (p) => {
          try {
            const scanRes = await fetch(`/api/projects/${p.id}/scan`);
            if (!scanRes.ok) return { ...p };
            const scan = await scanRes.json();
            const history: TaskEntry[] | null = scan.history;

            let taskCount = 0;
            let completedCount = 0;
            let latestActivity = "";
            let latestStatus = "";

            if (history && history.length > 0) {
              taskCount = history.length;
              completedCount = history.filter((t: TaskEntry) => {
                const last = t.logs[t.logs.length - 1];
                return last && last.status === "완료";
              }).length;

              const latest = history[history.length - 1];
              const lastLog = latest.logs[latest.logs.length - 1];
              if (lastLog) {
                latestActivity = `${latest.name || latest.slug} - ${lastLog.phase} ${lastLog.status}`;
                latestStatus = lastLog.status;
              }
            }

            return { ...p, history, taskCount, completedCount, latestActivity, latestStatus };
          } catch {
            return { ...p };
          }
        })
      );

      setProjects(enriched);
    } catch {
      // silent fail
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchProjects();
  }, [fetchProjects]);

  const handleProjectCreated = useCallback((_project: Project) => {
    setTimeout(() => fetchProjects(), 300);
  }, [fetchProjects]);

  const handleDelete = useCallback(async () => {
    if (!deleteTarget) return;
    try {
      await fetch(`/api/projects/${deleteTarget.id}`, { method: "DELETE" });
      setProjects((prev) => prev.filter((p) => p.id !== deleteTarget.id));
    } catch {
      // silent fail
    }
    setDeleteTarget(null);
  }, [deleteTarget]);

  return (
    <div className="flex min-h-screen">
      <Sidebar collapsed={sidebarCollapsed} onToggle={() => setSidebarCollapsed(!sidebarCollapsed)} />

      <main className="flex-1 p-6 sm:p-8 overflow-auto">
        <div className="flex justify-between items-center mb-6">
          <div>
            <h1 className="text-2xl sm:text-3xl font-bold text-slate-800">내 프로젝트</h1>
            <p className="text-sm text-slate-400 mt-0.5">
              {projects.length > 0 ? `${projects.length}개 프로젝트 관리 중` : "프로젝트를 등록하세요"}
            </p>
          </div>
          <button
            onClick={() => setModalOpen(true)}
            className="bg-primary-600 hover:bg-primary-700 text-white text-sm font-bold px-4 py-2.5 rounded-xl flex items-center gap-2 transition-colors shadow-sm"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path d="M12 4v16m8-8H4" strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} />
            </svg>
            <span className="hidden sm:inline">새 프로젝트</span>
          </button>
        </div>

        {loading && (
          <div className="py-20 text-center">
            <p className="text-slate-400 font-medium">프로젝트를 불러오는 중...</p>
          </div>
        )}

        {!loading && (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
            {projects.map((project) => (
              <ProjectCard key={project.id} project={project} onDelete={setDeleteTarget} />
            ))}

            <div
              onClick={() => setModalOpen(true)}
              className="border-2 border-dashed border-slate-200 rounded-xl p-5 flex flex-col items-center justify-center text-slate-400 hover:border-primary-300 hover:text-primary-500 transition-all cursor-pointer min-h-[200px]"
            >
              <svg className="w-8 h-8 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path d="M12 4v16m8-8H4" strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} />
              </svg>
              <span className="text-sm font-medium">새 프로젝트 추가</span>
            </div>
          </div>
        )}
      </main>

      <AddProjectModal open={modalOpen} onClose={() => setModalOpen(false)} onCreated={handleProjectCreated} />
      <DeleteConfirmModal project={deleteTarget} onClose={() => setDeleteTarget(null)} onConfirm={handleDelete} />
    </div>
  );
}
