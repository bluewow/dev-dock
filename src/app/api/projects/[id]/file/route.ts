import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import path from "path";
import { findProject, isPathSafe } from "@/lib/projects";

// GET /api/projects/[id]/file?path=... - HTML 파일 서빙
export async function GET(
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

  const filePath = request.nextUrl.searchParams.get("path");
  if (!filePath) {
    return NextResponse.json(
      { error: "파일 경로가 필요합니다." },
      { status: 400 }
    );
  }

  // Path traversal 방지
  if (!isPathSafe(project.path, filePath)) {
    return NextResponse.json(
      { error: "허용되지 않는 경로입니다." },
      { status: 403 }
    );
  }

  const absolutePath = path.resolve(project.path, filePath);

  if (!fs.existsSync(absolutePath)) {
    return NextResponse.json(
      { error: "파일을 찾을 수 없습니다." },
      { status: 404 }
    );
  }

  try {
    const content = fs.readFileSync(absolutePath, "utf-8");
    const ext = path.extname(absolutePath).toLowerCase();

    let contentType = "text/plain";
    if (ext === ".html" || ext === ".htm") contentType = "text/html";
    else if (ext === ".json") contentType = "application/json";
    else if (ext === ".md") contentType = "text/markdown";
    else if (ext === ".css") contentType = "text/css";
    else if (ext === ".js") contentType = "application/javascript";

    return new NextResponse(content, {
      headers: {
        "Content-Type": `${contentType}; charset=utf-8`,
      },
    });
  } catch {
    return NextResponse.json(
      { error: "파일을 읽을 수 없습니다." },
      { status: 500 }
    );
  }
}
