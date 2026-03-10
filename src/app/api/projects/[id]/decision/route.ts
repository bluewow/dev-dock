import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import path from "path";
import { findProject, TaskEntry } from "@/lib/projects";

// POST /api/projects/[id]/decision - 의사결정 기록
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const project = findProject(id);

  if (!project) {
    return NextResponse.json(
      { error: "프로젝트를 찾을 수 없습니다." },
      { status: 404 }
    );
  }

  try {
    const body = await request.json();
    const { taskSlug, decision, note } = body;

    if (!taskSlug || !decision) {
      return NextResponse.json(
        { error: "taskSlug과 decision은 필수입니다." },
        { status: 400 }
      );
    }

    const validDecisions = ["승인", "반려", "조건부승인"];
    if (!validDecisions.includes(decision)) {
      return NextResponse.json(
        { error: "decision은 승인, 반려, 조건부승인 중 하나여야 합니다." },
        { status: 400 }
      );
    }

    const historyPath = path.join(project.path, "docs", "history.json");

    if (!fs.existsSync(historyPath)) {
      return NextResponse.json(
        { error: "해당 프로젝트에 history.json이 없습니다." },
        { status: 404 }
      );
    }

    const history: TaskEntry[] = JSON.parse(
      fs.readFileSync(historyPath, "utf-8")
    );

    // Find task by slug
    const task = history.find(
      (t) => t.slug === taskSlug || t.id === taskSlug
    );

    if (!task) {
      return NextResponse.json(
        { error: "해당 태스크를 찾을 수 없습니다." },
        { status: 404 }
      );
    }

    // Add decision log
    const today = new Date().toISOString().split("T")[0];
    task.logs.push({
      phase: "승인",
      status: decision,
      date: today,
      note: note || "",
    });

    // Write back
    fs.writeFileSync(historyPath, JSON.stringify(history, null, 2), "utf-8");

    return NextResponse.json({ success: true, task });
  } catch {
    return NextResponse.json(
      { error: "의사결정을 기록할 수 없습니다." },
      { status: 500 }
    );
  }
}
