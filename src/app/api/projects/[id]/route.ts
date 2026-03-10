import { NextRequest, NextResponse } from "next/server";
import { readProjects, writeProjects } from "@/lib/projects";

// DELETE /api/projects/[id] - 프로젝트 등록 해제
export async function DELETE(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const projects = readProjects();
  const index = projects.findIndex((p) => p.id === id);

  if (index === -1) {
    return NextResponse.json(
      { error: "프로젝트를 찾을 수 없습니다." },
      { status: 404 }
    );
  }

  projects.splice(index, 1);
  writeProjects(projects);

  return NextResponse.json({ success: true });
}
