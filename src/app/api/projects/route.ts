import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import crypto from "crypto";
import { readProjects, writeProjects } from "@/lib/projects";

// GET /api/projects - 프로젝트 목록 조회
export async function GET() {
  const projects = readProjects();
  return NextResponse.json(projects);
}

// POST /api/projects - 새 프로젝트 등록
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { name, path: projectPath, color } = body;

    if (!name || !projectPath) {
      return NextResponse.json(
        { error: "프로젝트 이름과 경로는 필수입니다." },
        { status: 400 }
      );
    }

    // 경로 존재 여부 확인
    if (!fs.existsSync(projectPath)) {
      return NextResponse.json(
        { error: "해당 경로가 존재하지 않습니다." },
        { status: 400 }
      );
    }

    // 중복 경로 방지
    const projects = readProjects();
    const normalizedPath = projectPath.replace(/\\/g, "/").replace(/\/+$/, "");
    const duplicate = projects.find(
      (p) => p.path.replace(/\\/g, "/").replace(/\/+$/, "") === normalizedPath
    );
    if (duplicate) {
      return NextResponse.json(
        { error: "이미 등록된 경로입니다." },
        { status: 400 }
      );
    }

    const now = new Date().toISOString();
    const newProject = {
      id: crypto.randomUUID(),
      name: name.trim(),
      path: projectPath,
      color: color || "emerald",
      createdAt: now,
      updatedAt: now,
    };

    projects.push(newProject);
    writeProjects(projects);

    return NextResponse.json(newProject, { status: 201 });
  } catch {
    return NextResponse.json(
      { error: "요청을 처리할 수 없습니다." },
      { status: 500 }
    );
  }
}
