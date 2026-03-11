#!/bin/bash
# Devdock 배포 스크립트
# 사용법: ./deploy.sh <버전>
# 예시: ./deploy.sh 1.1.0

set -e

# 버전 인자 확인
if [ -z "$1" ]; then
  echo "사용법: ./deploy.sh <버전>"
  echo "예시: ./deploy.sh 1.1.0"
  exit 1
fi

VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FLUTTER_DIR="$SCRIPT_DIR/flutter_app"
INSTALLER_DIR="$SCRIPT_DIR/installer"
ISS_FILE="$INSTALLER_DIR/devdock_setup.iss"
ISCC_PATH="C:/Users/enliple/AppData/Local/Programs/Inno Setup 6/ISCC.exe"
DIST_DIR="$SCRIPT_DIR/dist"

echo "========================================"
echo "  Devdock 배포 v${VERSION}"
echo "========================================"
echo ""

# 1. ISS 파일 버전 업데이트
echo "[1/4] ISS 파일 버전 업데이트..."
sed -i "s/#define MyAppVersion \".*\"/#define MyAppVersion \"${VERSION}\"/" "$ISS_FILE"
echo "  → ${ISS_FILE} 버전: ${VERSION}"

# 2. pubspec.yaml 버전 업데이트
echo "[2/4] pubspec.yaml 버전 업데이트..."
sed -i "s/^version: .*/version: ${VERSION}/" "$FLUTTER_DIR/pubspec.yaml"
echo "  → pubspec.yaml 버전: ${VERSION}"

# 3. 기존 dist 파일 정리
echo "[3/5] 기존 배포 파일 정리..."
mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR"/*.exe
echo "  → dist/ 폴더 정리 완료"

# 4. Flutter 빌드
echo "[4/5] Flutter Windows 빌드..."
cd "$FLUTTER_DIR"
flutter build windows --release
echo "  → 빌드 완료"

# 5. Inno Setup 컴파일
echo "[5/5] 인스톨러 생성..."
"$ISCC_PATH" "$ISS_FILE"
echo "  → 인스톨러 생성 완료"

echo ""
echo "========================================"
echo "  배포 완료!"
echo "  출력: dist/DevdockSetup-${VERSION}.exe"
echo "========================================"
