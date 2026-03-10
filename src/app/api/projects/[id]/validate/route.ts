import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import path from "path";

// GET /api/projects/[id]/validate?path=... - 경로 유효성 확인
export async function GET(request: NextRequest) {
  const projectPath = request.nextUrl.searchParams.get("path");

  if (!projectPath) {
    return NextResponse.json(
      { valid: false, hasDocs: false, message: "경로가 필요합니다." },
      { status: 400 }
    );
  }

  if (!fs.existsSync(projectPath)) {
    return NextResponse.json({
      valid: false,
      hasDocs: false,
      message: "해당 경로가 존재하지 않습니다.",
    });
  }

  const stat = fs.statSync(projectPath);
  if (!stat.isDirectory()) {
    return NextResponse.json({
      valid: false,
      hasDocs: false,
      message: "경로가 디렉토리가 아닙니다.",
    });
  }

  const docsDir = path.join(projectPath, "docs");
  const hasDocs = fs.existsSync(docsDir);

  return NextResponse.json({
    valid: true,
    hasDocs,
    message: hasDocs
      ? "경로 확인됨 - docs/ 폴더 발견"
      : "경로 확인됨 - docs/ 폴더 없음 (산출물 없이 등록 가능)",
  });
}
