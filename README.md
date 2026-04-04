<p align="center">
  <img src="build/icon_256x256@2x.png" width="128" height="128" alt="Doffice">
</p>

<h1 align="center">Doffice</h1>

<p align="center">
  <strong>Claude Code 세션을 시각적으로 관리하는 Windows 데스크톱 앱</strong><br>
  <sub>`dev` 브랜치는 Windows 개발 기준, `main` 브랜치는 macOS 원본 기준으로 유지합니다.</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Windows%2010%2B-lightgrey?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/electron-35-blue?style=flat-square" alt="Electron">
  <img src="https://img.shields.io/badge/react-18-61dafb?style=flat-square" alt="React">
  <img src="https://img.shields.io/badge/vite-6-8b5cf6?style=flat-square" alt="Vite">
</p>

---

## 브랜치 운영

- `dev`
  Windows 버전 개발 브랜치입니다. 저장소 루트가 곧 실제 앱 루트입니다.
- `main`
  macOS 원본 기준 브랜치입니다. SwiftUI/Xcode 구현을 참고할 때만 전환해서 확인합니다.

즉 `dev`에서는 이 저장소 루트에서 바로 개발하고, mac 원본을 참고할 때만 `main`으로 전환합니다.

---

## 개발 시작

```bash
git switch dev
npm install
```

실행:

```bash
npm start
```

검증:

```bash
npm run typecheck
```

빌드:

```bash
npm run build
```

설치형 exe 패키징:

```bash
npm run dist:win
```

포터블 exe 패키징:

```bash
npm run pack:win
```

---

## 산출물 위치

- 프론트 빌드: `dist/`
- Electron 메인 빌드: `dist-electron/`
- unpacked 실행본: `release/win-unpacked/Doffice.exe`
- 설치형 패키지: `release/Doffice Setup <version>.exe`

---

## mac 버전 참고

mac 원본을 참고해야 할 때만:

```bash
git switch main
```

Windows 개발로 돌아올 때:

```bash
git switch dev
```

---

## 기술 스택

- Electron
- React 18
- Vite
- TypeScript
- Claude Code CLI 연동

---

## 라이선스

MIT
