# Milestone - Project Management Hub

## Tech Stack
- **Framework**: Next.js 16.1.6 (App Router)
- **Language**: TypeScript (strict mode)
- **Styling**: Tailwind CSS v4 (postcss plugin)
- **Font**: Pretendard (CDN: cdn.jsdelivr.net)
- **Data**: localStorage (client-side) + Next.js API Routes (file system read)
- **Package Manager**: npm
- **Node**: ES2017 target, bundler module resolution
- **Path Alias**: `@/*` -> `./src/*`

## Style Guide
- **Primary Color**: indigo (50~700), see globals.css @theme
- **Background**: #f8fafc (slate-50)
- **Foreground**: #1e293b (slate-800)
- **Font Family**: Pretendard, system fallbacks
- **Border Radius**: rounded-xl (cards), rounded-2xl (sections), rounded-lg (inputs)
- **Shadows**: shadow-sm (cards), shadow-lg (buttons)
- **Animation**: slideIn (0.3s ease-out), progress-fill-transition (0.6s cubic-bezier)
- **Language**: Korean (lang="ko"), UI labels mix Korean/English

## Patterns & Conventions
- Single page.tsx with "use client" for interactive pages
- Component logic co-located in page file (no separate component files yet)
- Interface/Type definitions at top of file
- Constants after types
- Helper functions before component
- Tailwind classes inline (no CSS modules)
- localStorage for client-side persistence
- SVG icons inline (no icon library)
- Form state with useState hooks
- useCallback for event handlers
- Confirmation dialog for destructive actions

## Project Structure
```
src/
  app/
    layout.tsx       # RootLayout, Pretendard font, globals.css
    page.tsx         # Main dashboard (client component)
    globals.css      # Tailwind imports + custom theme + animations
docs/
    history.json     # Task history log
    history.html     # History viewer
    tasks/           # Task deliverables (plan.html, design.html, spec.md)
    data/            # User-provided reference materials
```

## Git
- Commit messages in Korean, conventional style
- Co-Authored-By header required
