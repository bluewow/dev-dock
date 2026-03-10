"use client";

import { useState, useEffect, useCallback } from "react";

// ─── Types ────────────────────────────────────────────────────────────────────
interface Task {
  id: number;
  date: string;
  title: string;
  body: string;
  completed: boolean;
}

// ─── Constants ────────────────────────────────────────────────────────────────
const STORAGE_KEY = "taskflow-tasks";

const MILESTONES = [
  { position: 15, label: "Oct 1", passed: true },
  { position: 40, label: "Oct 15", passed: true },
  { position: 70, label: "Nov 5", passed: false },
  { position: 90, label: "Nov 20", passed: false },
];

// ─── Helpers ──────────────────────────────────────────────────────────────────
function loadTasks(): Task[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch {
    // corrupted data, reset
  }
  return [];
}

function saveTasks(tasks: Task[]) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(tasks));
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function Home() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [mounted, setMounted] = useState(false);

  // Form state
  const [formDate, setFormDate] = useState("");
  const [formTitle, setFormTitle] = useState("");
  const [formBody, setFormBody] = useState("");

  // Delete confirmation
  const [deleteTarget, setDeleteTarget] = useState<number | null>(null);

  // Load from localStorage on mount
  useEffect(() => {
    setMounted(true);
    const stored = loadTasks();
    if (stored.length > 0) {
      setTasks(stored);
    }
  }, []);

  // Save to localStorage whenever tasks change (after mount)
  useEffect(() => {
    if (mounted) {
      saveTasks(tasks);
    }
  }, [tasks, mounted]);

  // Progress calculation
  const completedCount = tasks.filter((t) => t.completed).length;
  const progressPercent =
    tasks.length === 0 ? 0 : Math.round((completedCount / tasks.length) * 100);

  // Handlers
  const handleSubmit = useCallback(
    (e: React.FormEvent) => {
      e.preventDefault();
      if (!formDate || !formTitle.trim()) return;

      const newTask: Task = {
        id: Date.now(),
        date: formDate,
        title: formTitle.trim().slice(0, 100),
        body: formBody.trim().slice(0, 500),
        completed: false,
      };

      setTasks((prev) => [newTask, ...prev]);
      setFormDate("");
      setFormTitle("");
      setFormBody("");
    },
    [formDate, formTitle, formBody]
  );

  const toggleTask = useCallback((id: number) => {
    setTasks((prev) =>
      prev.map((t) => (t.id === id ? { ...t, completed: !t.completed } : t))
    );
  }, []);

  const requestDelete = useCallback((id: number) => {
    setDeleteTarget(id);
  }, []);

  const confirmDelete = useCallback(() => {
    if (deleteTarget !== null) {
      setTasks((prev) => prev.filter((t) => t.id !== deleteTarget));
      setDeleteTarget(null);
    }
  }, [deleteTarget]);

  const cancelDelete = useCallback(() => {
    setDeleteTarget(null);
  }, []);

  return (
    <div className="min-h-full flex flex-col">
      {/* ── Top Navigation ──────────────────────────────────────────── */}
      <nav className="bg-white border-b border-slate-200 px-4 sm:px-8 py-4 flex justify-between items-center sticky top-0 z-50">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center">
            <svg
              className="w-5 h-5 text-white"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                d="M5 13l4 4L19 7"
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
              />
            </svg>
          </div>
          <span className="text-xl font-bold tracking-tight text-slate-800">
            TaskFlow
          </span>
        </div>
        <div className="flex items-center gap-4">
          <button className="p-2 text-slate-400 hover:text-indigo-600 transition-colors">
            <svg
              className="w-6 h-6"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
              />
            </svg>
          </button>
          <div className="w-10 h-10 rounded-full bg-indigo-100 border border-indigo-200 flex items-center justify-center text-indigo-700 font-semibold">
            JD
          </div>
        </div>
      </nav>

      {/* ── Main Content ────────────────────────────────────────────── */}
      <main className="flex-1 max-w-6xl w-full mx-auto p-4 sm:p-8 space-y-8 sm:space-y-12">
        {/* ── Progress Section ──────────────────────────────────────── */}
        <section className="space-y-6 pb-4 sm:pb-8">
          <div className="flex justify-between items-end">
            <div>
              <h1 className="text-2xl sm:text-3xl font-bold text-slate-800">
                Project Momentum
              </h1>
              <p className="text-slate-500 mt-1 text-sm sm:text-base">
                Daily task completion progress
              </p>
            </div>
            <div className="text-right">
              <span className="text-3xl sm:text-4xl font-black text-indigo-600">
                {progressPercent}%
              </span>
              <p className="text-xs uppercase tracking-widest font-bold text-slate-400">
                Completed
              </p>
            </div>
          </div>

          {/* Arrow Progress Bar */}
          <div className="relative h-16 sm:h-24 w-full flex items-center">
            {/* Background Arrow */}
            <div
              className="absolute inset-0 bg-slate-200"
              style={{
                clipPath:
                  "polygon(0% 20%, 85% 20%, 85% 0%, 100% 50%, 85% 100%, 85% 80%, 0% 80%)",
              }}
            />
            {/* Fill Arrow */}
            <div
              className="absolute inset-0 bg-gradient-to-r from-indigo-500 via-purple-500 to-pink-500 progress-fill-transition"
              style={{
                width: `${Math.max(progressPercent, 2)}%`,
                clipPath:
                  "polygon(0% 20%, 85% 20%, 85% 0%, 100% 50%, 85% 100%, 85% 80%, 0% 80%)",
              }}
            >
              <div className="absolute inset-0 bg-white/10 opacity-50" />
            </div>

            {/* Milestones */}
            <div className="absolute inset-0 w-full h-full">
              {MILESTONES.map((ms, i) => (
                <div
                  key={i}
                  className="absolute top-1/2 -translate-y-1/2 flex flex-col items-center"
                  style={{ left: `${ms.position}%` }}
                >
                  <div
                    className={`w-4 h-4 rounded-full bg-white border-2 shadow-sm ${
                      ms.passed ? "border-indigo-600" : "border-slate-400"
                    }`}
                  />
                  <span className="absolute top-10 sm:top-12 text-xs font-bold text-slate-400 whitespace-nowrap">
                    {ms.label}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* ── Grid: Form + Task List ────────────────────────────────── */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 sm:gap-8 items-start">
          {/* ── Task Entry Form ──────────────────────────────────────── */}
          <section className="lg:col-span-1 bg-white p-6 rounded-2xl shadow-sm border border-slate-200">
            <h2 className="text-lg font-semibold mb-6 flex items-center gap-2">
              <svg
                className="w-5 h-5 text-indigo-500"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  d="M12 4v16m8-8H4"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                />
              </svg>
              Add New Task
            </h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase text-slate-400 mb-1">
                  Due Date
                </label>
                <input
                  type="date"
                  value={formDate}
                  onChange={(e) => setFormDate(e.target.value)}
                  required
                  className="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-shadow"
                />
              </div>
              <div>
                <label className="block text-xs font-bold uppercase text-slate-400 mb-1">
                  Task Title
                </label>
                <input
                  type="text"
                  value={formTitle}
                  onChange={(e) => setFormTitle(e.target.value)}
                  placeholder="예: 디자인 리뷰"
                  required
                  maxLength={100}
                  className="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-shadow"
                />
              </div>
              <div>
                <label className="block text-xs font-bold uppercase text-slate-400 mb-1">
                  Details
                </label>
                <textarea
                  value={formBody}
                  onChange={(e) => setFormBody(e.target.value)}
                  placeholder="태스크 상세 설명..."
                  rows={3}
                  maxLength={500}
                  className="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-shadow resize-none"
                />
              </div>
              <button
                type="submit"
                className="w-full py-3 bg-indigo-600 hover:bg-indigo-700 text-white font-bold rounded-xl transition-all shadow-lg shadow-indigo-200 active:scale-[0.98]"
              >
                Create Task
              </button>
            </form>
          </section>

          {/* ── Task List ────────────────────────────────────────────── */}
          <section className="lg:col-span-2 space-y-4">
            <div className="flex justify-between items-center px-2">
              <h2 className="text-lg font-semibold text-slate-700">
                Your Backlog
              </h2>
              <div className="flex gap-2">
                <span className="px-3 py-1 bg-slate-100 text-slate-500 rounded-full text-xs font-medium">
                  Sort: Newest
                </span>
              </div>
            </div>

            <div className="space-y-4">
              {/* Loading / not mounted yet */}
              {!mounted && (
                <div className="py-20 text-center border-2 border-dashed border-slate-200 rounded-2xl">
                  <p className="text-slate-400 font-medium">Loading...</p>
                </div>
              )}

              {/* Empty state */}
              {mounted && tasks.length === 0 && (
                <div className="py-20 text-center border-2 border-dashed border-slate-200 rounded-2xl">
                  <div className="text-slate-300 mb-3">
                    <svg
                      className="w-12 h-12 mx-auto"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                      />
                    </svg>
                  </div>
                  <p className="text-slate-400 font-medium">
                    아직 태스크가 없습니다. 새 태스크를 추가해보세요!
                  </p>
                </div>
              )}

              {/* Task cards */}
              {mounted &&
                tasks.map((task) => (
                  <div
                    key={task.id}
                    className={`task-card-animate flex items-start gap-4 bg-white p-5 rounded-2xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow ${
                      task.completed ? "opacity-75" : ""
                    }`}
                  >
                    {/* Checkbox with enlarged touch area (44px) */}
                    <div className="pt-0.5">
                      <label className="flex items-center justify-center w-11 h-11 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={task.completed}
                          onChange={() => toggleTask(task.id)}
                          className="w-6 h-6 rounded-lg text-indigo-600 border-slate-300 focus:ring-indigo-500 cursor-pointer"
                        />
                      </label>
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex justify-between items-start gap-2">
                        <div className="min-w-0">
                          <h3
                            className={`font-bold text-slate-800 truncate ${
                              task.completed ? "line-through" : ""
                            }`}
                          >
                            {task.title}
                          </h3>
                          <p className="text-xs text-indigo-500 font-semibold mb-2">
                            {task.date}
                          </p>
                        </div>
                        <button
                          onClick={() => requestDelete(task.id)}
                          className="text-slate-300 hover:text-red-500 transition-colors flex-shrink-0 p-1"
                          aria-label="태스크 삭제"
                        >
                          <svg
                            className="w-5 h-5"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              strokeWidth={2}
                              d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                            />
                          </svg>
                        </button>
                      </div>
                      {task.body && (
                        <p className="text-sm text-slate-600 leading-relaxed break-words">
                          {task.body}
                        </p>
                      )}
                    </div>
                  </div>
                ))}
            </div>
          </section>
        </div>
      </main>

      {/* ── Footer ──────────────────────────────────────────────────── */}
      <footer className="bg-white border-t border-slate-200 py-6 text-center">
        <p className="text-sm text-slate-400">
          &copy; 2026 TaskFlow. Built for high performance.
        </p>
      </footer>

      {/* ── Delete Confirmation Dialog ──────────────────────────────── */}
      {deleteTarget !== null && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-2xl shadow-xl p-6 mx-4 max-w-sm w-full space-y-4">
            <h3 className="text-lg font-bold text-slate-800">
              태스크를 삭제할까요?
            </h3>
            <p className="text-sm text-slate-600">
              삭제된 태스크는 복구할 수 없습니다.
            </p>
            <div className="flex gap-3 justify-end">
              <button
                onClick={cancelDelete}
                className="px-4 py-2 text-sm font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
              >
                취소
              </button>
              <button
                onClick={confirmDelete}
                className="px-4 py-2 text-sm font-medium text-white bg-red-500 hover:bg-red-600 rounded-xl transition-colors"
              >
                삭제
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
