"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";

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
  reviews?: string[];
  spec?: string;
  id?: string;
  path?: string;
}

interface ScannedFile {
  name: string;
  relativePath: string;
  type: "html" | "md" | "json" | "other";
  size: number;
  modifiedAt: string;
}

interface ScannedTask {
  slug: string;
  files: ScannedFile[];
  hasSpec: boolean;
}

// ─── Color Map ────────────────────────────────────────────────────────────────

const COLOR_MAP: Record<string, string> = {
  emerald: "bg-emerald-400",
  blue: "bg-blue-400",
  purple: "bg-purple-400",
  amber: "bg-amber-400",
  rose: "bg-rose-400",
  slate: "bg-slate-400",
};

// ─── Status Badge ─────────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: string }) {
  const map: Record<string, { bg: string; text: string }> = {
    "완료": { bg: "bg-emerald-50", text: "text-emerald-700" },
    "승인": { bg: "bg-emerald-50", text: "text-emerald-700" },
    "조건부승인": { bg: "bg-amber-50", text: "text-amber-700" },
    "진행중": { bg: "bg-purple-50", text: "text-purple-700" },
    "반려": { bg: "bg-red-50", text: "text-red-700" },
  };
  const s = map[status] || { bg: "bg-slate-50", text: "text-slate-700" };
  return <span className={`text-xs ${s.bg} ${s.text} px-1.5 py-0.5 rounded font-medium`}>{status}</span>;
}

// ─── Sidebar (Collapsed) ─────────────────────────────────────────────────────

function CollapsedSidebar() {
  return (
    <aside className="w-14 bg-white border-r border-slate-200 flex flex-col items-center py-4 flex-shrink-0 h-screen sticky top-0">
      <Link href="/" className="w-8 h-8 bg-primary-600 rounded-lg flex items-center justify-center mb-6">
        <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} />
        </svg>
      </Link>
      <div className="space-y-3">
        <Link href="/" className="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center text-slate-400 hover:bg-slate-200 transition-colors">
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} />
          </svg>
        </Link>
        <div className="w-9 h-9 rounded-xl bg-primary-50 flex items-center justify-center text-primary-600">
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} />
          </svg>
        </div>
      </div>
    </aside>
  );
}

// ─── Decision Bar ─────────────────────────────────────────────────────────────

function DecisionBar({
  projectId,
  taskSlug,
  onDecision,
}: {
  projectId: string;
  taskSlug: string;
  onDecision: () => void;
}) {
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const handleDecision = useCallback(async (decision: string) => {
    setSubmitting(true);
    try {
      const res = await fetch(`/api/projects/${projectId}/decision`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ taskSlug, decision, note }),
      });
      if (res.ok) {
        setNote("");
        onDecision();
      }
    } catch {
      // silent
    }
    setSubmitting(false);
  }, [projectId, taskSlug, note, onDecision]);

  return (
    <div className="bg-white border-t border-slate-200 px-5 py-3">
      <div className="flex items-center gap-3">
        <div className="flex-1">
          <input
            type="text"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder="코멘트를 입력하세요..."
            className="w-full text-sm border border-slate-200 rounded-xl px-3 py-2 focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
          />
        </div>
        <button
          onClick={() => handleDecision("반려")}
          disabled={submitting}
          className="px-4 py-2 text-sm font-bold text-red-600 bg-red-50 hover:bg-red-100 rounded-xl transition-colors disabled:opacity-50"
        >
          반려
        </button>
        <button
          onClick={() => handleDecision("승인")}
          disabled={submitting}
          className="px-4 py-2 text-sm font-bold text-white bg-primary-600 hover:bg-primary-700 rounded-xl transition-colors shadow-sm disabled:opacity-50"
        >
          승인
        </button>
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function ProjectDetail() {
  const params = useParams();
  const projectId = params.id as string;

  const [project, setProject] = useState<Project | null>(null);
  const [tasks, setTasks] = useState<ScannedTask[]>([]);
  const [history, setHistory] = useState<TaskEntry[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Selected task & file
  const [selectedTask, setSelectedTask] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<string | null>(null);
  const [viewerUrl, setViewerUrl] = useState<string | null>(null);

  // Active tab in task panel
  const [activeTab, setActiveTab] = useState<"tasks" | "artifacts" | "history">("tasks");

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      // Fetch project
      const projRes = await fetch("/api/projects");
      const projects: Project[] = await projRes.json();
      const proj = projects.find((p) => p.id === projectId);
      if (!proj) {
        setError("프로젝트를 찾을 수 없습니다.");
        setLoading(false);
        return;
      }
      setProject(proj);

      // Fetch scan
      const scanRes = await fetch(`/api/projects/${projectId}/scan`);
      if (scanRes.ok) {
        const scan = await scanRes.json();
        setTasks(scan.tasks || []);
        setHistory(scan.history || null);
      }
    } catch {
      setError("데이터를 불러올 수 없습니다.");
    }
    setLoading(false);
  }, [projectId]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Open file in viewer
  const openFile = useCallback((filePath: string, taskSlug: string) => {
    setSelectedFile(filePath);
    setSelectedTask(taskSlug);
    setViewerUrl(`/api/projects/${projectId}/file?path=${encodeURIComponent(filePath)}`);
  }, [projectId]);

  // Get history entry for a task
  const getHistoryEntry = useCallback((slug: string): TaskEntry | undefined => {
    if (!history) return undefined;
    return history.find((h) => {
      const taskId = h.id || h.slug;
      return slug.includes(taskId) || slug.includes(h.slug);
    });
  }, [history]);

  // Get last status for a task
  const getLastStatus = useCallback((slug: string): string => {
    const entry = getHistoryEntry(slug);
    if (!entry || entry.logs.length === 0) return "미확인";
    return entry.logs[entry.logs.length - 1].status;
  }, [getHistoryEntry]);

  if (loading) {
    return (
      <div className="flex min-h-screen">
        <CollapsedSidebar />
        <div className="flex-1 flex items-center justify-center">
          <p className="text-slate-400">불러오는 중...</p>
        </div>
      </div>
    );
  }

  if (error || !project) {
    return (
      <div className="flex min-h-screen">
        <CollapsedSidebar />
        <div className="flex-1 flex items-center justify-center">
          <div className="text-center">
            <p className="text-slate-400 mb-4">{error || "프로젝트를 찾을 수 없습니다."}</p>
            <Link href="/" className="text-primary-600 text-sm font-medium hover:underline">대시보드로 돌아가기</Link>
          </div>
        </div>
      </div>
    );
  }

  const dotColor = COLOR_MAP[project.color] || COLOR_MAP.emerald;

  return (
    <div className="flex min-h-screen">
      <CollapsedSidebar />

      {/* Task List Panel */}
      <div className="w-72 bg-white border-r border-slate-200 flex flex-col flex-shrink-0 h-screen sticky top-0 overflow-hidden">
        {/* Project Header */}
        <div className="px-4 py-4 border-b border-slate-100 flex-shrink-0">
          <Link href="/" className="flex items-center gap-2 text-xs text-slate-400 mb-2 hover:text-primary-600 transition-colors">
            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            프로젝트 목록
          </Link>
          <div className="flex items-center gap-2">
            <div className={`w-2.5 h-2.5 rounded-full ${dotColor}`} />
            <h2 className="font-bold text-base">{project.name}</h2>
          </div>
          <p className="text-xs text-slate-400 mt-1 font-mono truncate">{project.path}</p>
        </div>

        {/* Tab Bar */}
        <div className="flex border-b border-slate-100 flex-shrink-0">
          {(["tasks", "artifacts", "history"] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`flex-1 text-center py-2.5 text-xs transition-colors ${
                activeTab === tab
                  ? "font-bold text-primary-600 border-b-2 border-primary-600"
                  : "text-slate-400 hover:text-slate-600"
              }`}
            >
              {tab === "tasks" ? "태스크" : tab === "artifacts" ? "산출물" : "이력"}
            </button>
          ))}
        </div>

        {/* Tab Content */}
        <div className="flex-1 overflow-auto p-3 space-y-2">
          {/* Tasks Tab */}
          {activeTab === "tasks" && (
            <>
              <div className="text-xs font-bold text-slate-400 uppercase tracking-wider px-2 py-1">
                태스크 목록 ({tasks.length})
              </div>
              {tasks.length === 0 && (
                <div className="py-8 text-center text-xs text-slate-400">산출물이 없습니다</div>
              )}
              {tasks.map((task) => {
                const lastStatus = getLastStatus(task.slug);
                const isSelected = selectedTask === task.slug;

                return (
                  <div
                    key={task.slug}
                    className={`rounded-xl border p-3 cursor-pointer transition-all ${
                      isSelected
                        ? "border-2 border-primary-300 bg-primary-50/50"
                        : "border-slate-200 hover:bg-slate-50"
                    }`}
                    onClick={() => {
                      setSelectedTask(task.slug);
                      // Auto-open first HTML file
                      const htmlFile = task.files.find((f) => f.type === "html");
                      if (htmlFile) openFile(htmlFile.relativePath, task.slug);
                    }}
                  >
                    <div className="flex items-center justify-between mb-1.5">
                      <StatusBadge status={lastStatus} />
                      {task.hasSpec && (
                        <span className="text-[10px] bg-emerald-50 text-emerald-600 px-1.5 py-0.5 rounded font-medium">spec</span>
                      )}
                    </div>
                    <div className="font-bold text-sm text-slate-700">{task.slug}</div>
                    <div className="flex flex-wrap gap-1 mt-2">
                      {task.files.map((f) => (
                        <button
                          key={f.relativePath}
                          onClick={(e) => { e.stopPropagation(); openFile(f.relativePath, task.slug); }}
                          className={`text-[10px] px-1.5 py-0.5 rounded transition-colors ${
                            selectedFile === f.relativePath
                              ? "bg-primary-600 text-white"
                              : f.type === "html"
                                ? "bg-primary-50 text-primary-700 hover:bg-primary-100"
                                : f.type === "md"
                                  ? "bg-emerald-50 text-emerald-600 hover:bg-emerald-100"
                                  : "bg-slate-100 text-slate-500 hover:bg-slate-200"
                          }`}
                        >
                          {f.name}
                        </button>
                      ))}
                    </div>
                  </div>
                );
              })}
            </>
          )}

          {/* Artifacts Tab */}
          {activeTab === "artifacts" && (
            <>
              <div className="text-xs font-bold text-slate-400 uppercase tracking-wider px-2 py-1">
                전체 산출물
              </div>
              {tasks.flatMap((task) =>
                task.files.map((f) => (
                  <button
                    key={f.relativePath}
                    onClick={() => openFile(f.relativePath, task.slug)}
                    className={`w-full text-left rounded-xl border p-3 transition-all ${
                      selectedFile === f.relativePath
                        ? "border-primary-300 bg-primary-50/50"
                        : "border-slate-200 hover:bg-slate-50"
                    }`}
                  >
                    <div className="flex items-center gap-2 mb-1">
                      <svg className="w-3.5 h-3.5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} />
                      </svg>
                      <span className="text-sm font-medium text-slate-700">{f.name}</span>
                    </div>
                    <div className="flex items-center gap-2 text-[10px] text-slate-400">
                      <span>{task.slug}</span>
                      <span>{(f.size / 1024).toFixed(1)}KB</span>
                    </div>
                  </button>
                ))
              )}
            </>
          )}

          {/* History Tab */}
          {activeTab === "history" && (
            <>
              <div className="text-xs font-bold text-slate-400 uppercase tracking-wider px-2 py-1">
                이력
              </div>
              {!history || history.length === 0 ? (
                <div className="py-8 text-center text-xs text-slate-400">이력이 없습니다</div>
              ) : (
                history.map((entry) => (
                  <div key={entry.slug} className="rounded-xl border border-slate-200 p-3">
                    <div className="font-bold text-sm text-slate-700 mb-2">{entry.name || entry.slug}</div>
                    <div className="space-y-1.5">
                      {entry.logs.map((log, i) => (
                        <div key={i} className="flex items-start gap-2 text-xs">
                          <span className="w-1.5 h-1.5 rounded-full bg-slate-300 mt-1.5 flex-shrink-0" />
                          <div>
                            <span className="text-slate-400">{log.date}</span>{" "}
                            <span className="font-medium text-slate-600">{log.phase}</span>{" "}
                            <StatusBadge status={log.status} />
                            {log.note && <p className="text-slate-400 mt-0.5">{log.note}</p>}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ))
              )}
            </>
          )}
        </div>
      </div>

      {/* Viewer Area */}
      <div className="flex-1 flex flex-col h-screen">
        {viewerUrl ? (
          <>
            {/* Viewer Header */}
            <div className="bg-white border-b border-slate-200 px-5 py-3 flex items-center justify-between flex-shrink-0">
              <div className="flex items-center gap-3">
                <span className="text-xs bg-primary-100 text-primary-700 px-2 py-0.5 rounded-md font-medium">
                  {selectedFile?.split("/").pop()}
                </span>
                <span className="text-xs text-slate-400">{selectedTask}</span>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => { if (viewerUrl) window.open(viewerUrl, "_blank"); }}
                  className="p-1.5 rounded-lg text-slate-400 hover:bg-slate-100 hover:text-slate-600 transition-colors"
                  title="새 탭에서 열기"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} />
                  </svg>
                </button>
                <button
                  onClick={() => { setViewerUrl(null); setSelectedFile(null); }}
                  className="p-1.5 rounded-lg text-slate-400 hover:bg-slate-100 hover:text-slate-600 transition-colors"
                  title="닫기"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path d="M6 18L18 6M6 6l12 12" strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} />
                  </svg>
                </button>
              </div>
            </div>

            {/* iframe */}
            <div className="flex-1 overflow-hidden">
              <iframe
                src={viewerUrl}
                className="w-full h-full border-none"
                title="산출물 뷰어"
                sandbox="allow-scripts allow-same-origin"
              />
            </div>

            {/* Decision Bar */}
            {selectedTask && (
              <DecisionBar
                projectId={projectId}
                taskSlug={(() => {
                  const entry = getHistoryEntry(selectedTask);
                  return entry?.slug || entry?.id || selectedTask;
                })()}
                onDecision={fetchData}
              />
            )}
          </>
        ) : (
          <div className="flex-1 flex items-center justify-center bg-slate-50/50">
            <div className="text-center text-slate-400">
              <svg className="w-16 h-16 mx-auto mb-4 text-slate-200" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} />
              </svg>
              <p className="font-medium mb-1">산출물을 선택하세요</p>
              <p className="text-xs">왼쪽 목록에서 파일을 클릭하면 이 영역에 표시됩니다</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
