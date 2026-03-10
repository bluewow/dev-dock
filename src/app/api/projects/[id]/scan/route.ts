import { NextRequest, NextResponse } from "next/server";
import { findProject, scanDocsFolder } from "@/lib/projects";

// GET /api/projects/[id]/scan - 산출물 스캔
export async function GET(
  _request: NextRequest,
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
    const { tasks, history } = scanDocsFolder(project.path);

    return NextResponse.json({
      projectId: project.id,
      tasks,
      history,
    });
  } catch {
    return NextResponse.json(
      { error: "산출물을 스캔할 수 없습니다. 경로를 확인해주세요." },
      { status: 500 }
    );
  }
}
