import { useEffect, useMemo, useState, type FormEvent } from "react";
import { t } from "./localizationCatalog";
import type { NewSessionDraftState, NewSessionPresetId, NewSessionProjectRecord } from "./newSessionPreferences";
import { relativeTime } from "./sessionUtils";

const trustedProjectPathsKey = "doffice.new-session.trusted-project-paths";

interface NewSessionSheetProps {
  isOpen: boolean;
  busy: boolean;
  draft: NewSessionDraftState;
  favoriteProjects: NewSessionProjectRecord[];
  recentProjects: NewSessionProjectRecord[];
  isFavorite: boolean;
  onClose: () => void;
  onPickDirectory: () => void;
  onAddPluginDirectory: () => void;
  onSubmit: () => void | Promise<void>;
  onUpdateDraft: (patch: Partial<NewSessionDraftState>) => void;
  onChooseProject: (project: NewSessionProjectRecord) => void;
  onToggleFavorite: () => void;
  onApplyPreset: (preset: NewSessionPresetId) => void;
}

const presets: Array<{ id: NewSessionPresetId; title: string; subtitle: string; symbol: string; tone: string }> = [
  { id: "balanced", title: "terminal.preset.balanced", subtitle: "terminal.preset.balanced.desc", symbol: "🔨", tone: "accent" },
  { id: "planFirst", title: "terminal.preset.planfirst", subtitle: "terminal.preset.planfirst.desc", symbol: "📋", tone: "purple" },
  { id: "safeReview", title: "terminal.preset.safereview", subtitle: "terminal.preset.safereview.desc", symbol: "🛡", tone: "warning" },
  { id: "parallelBuild", title: "terminal.preset.parallelbuild", subtitle: "terminal.preset.parallelbuild.desc", symbol: "📄＋", tone: "green" }
];

const claudeModels = [
  { value: "opus", label: "Opus", icon: "●", tone: "purple" },
  { value: "sonnet", label: "Sonnet", icon: "●", tone: "blue" },
  { value: "haiku", label: "Haiku", icon: "●", tone: "green" }
];

const codexModels = [
  { value: "gpt-5.4", label: "GPT-5.4" },
  { value: "gpt-5.4-mini", label: "GPT-5.4-Mini" },
  { value: "gpt-5.3-codex", label: "GPT-5.3-Codex" },
  { value: "gpt-5.2-codex", label: "GPT-5.2-Codex" },
  { value: "gpt-5.2", label: "GPT-5.2" },
  { value: "gpt-5.1-codex-max", label: "GPT-5.1-Codex-Max" },
  { value: "gpt-5.1-codex-mini", label: "GPT-5.1-Codex-Mini" }
];

const geminiModels = [
  { value: "gemini-2.5-pro", label: "Gemini 2.5 Pro" },
  { value: "gemini-2.5-flash", label: "Gemini 2.5 Flash" }
];

const claudeEfforts = [
  { value: "low", label: "낮음", icon: "🐢", tone: "green" },
  { value: "medium", label: "보통", icon: "🚶", tone: "blue" },
  { value: "high", label: "높음", icon: "🏃", tone: "orange" },
  { value: "max", label: "최대", icon: "🔥", tone: "red" }
];

const claudePermissions = [
  { value: "acceptEdits", label: "수정만 허용", icon: "📝", tone: "orange", subtitle: "파일 수정 권한 자동 승인" },
  { value: "bypassPermissions", label: "전체 허용", icon: "⚡", tone: "yellow", subtitle: "모든 권한 자동 승인" },
  { value: "auto", label: "자동", icon: "⚙⚙", tone: "sky", subtitle: "상황에 따라 자동 판단" },
  { value: "default", label: "기본", icon: "🛡", tone: "default", subtitle: "위험 명령 승인 필요" },
  { value: "plan", label: "계획만", icon: "📋", tone: "purple", subtitle: "계획만 세우고 실행 안함" }
];

const codexSandboxes = [
  { value: "read-only", label: "읽기 전용", icon: "🗂", tone: "green" },
  { value: "workspace-write", label: "작업 폴더", icon: "🗂", tone: "sky" },
  { value: "danger-full-access", label: "전체 허용", icon: "🗂", tone: "red" }
];

const codexApprovals = [
  { value: "untrusted", label: "안전만", icon: "✋", tone: "green" },
  { value: "on-request", label: "필요 시", icon: "✋", tone: "orange" },
  { value: "never", label: "묻지 않음", icon: "✋", tone: "yellow" }
];

const terminalCounts = [1, 2, 3, 4, 5] as const;

function normalizeTrustedProjectPath(value: string) {
  return value.trim().replace(/[\\/]+$/, "").replace(/\\/g, "/").toLowerCase();
}

function loadTrustedProjectPaths() {
  try {
    const raw = window.localStorage.getItem(trustedProjectPathsKey);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as string[];
    return Array.isArray(parsed) ? parsed.filter((value): value is string => typeof value === "string" && value.trim().length > 0) : [];
  } catch {
    return [];
  }
}

function saveTrustedProjectPaths(paths: string[]) {
  window.localStorage.setItem(trustedProjectPathsKey, JSON.stringify(paths));
}

export function NewSessionSheet(props: NewSessionSheetProps) {
  const {
    isOpen,
    busy,
    draft,
    favoriteProjects,
    recentProjects,
    isFavorite,
    onClose,
    onPickDirectory,
    onAddPluginDirectory,
    onSubmit,
    onUpdateDraft,
    onChooseProject,
    onToggleFavorite,
    onApplyPreset
  } = props;
  const [showTrustPrompt, setShowTrustPrompt] = useState(false);
  const [trustedProjectPaths, setTrustedProjectPaths] = useState<string[]>(loadTrustedProjectPaths);

  if (!isOpen) return null;

  useEffect(() => {
    if (!isOpen) {
      setShowTrustPrompt(false);
    }
  }, [isOpen]);

  useEffect(() => {
    saveTrustedProjectPaths(trustedProjectPaths);
  }, [trustedProjectPaths]);

  const normalizedProjectPath = useMemo(() => normalizeTrustedProjectPath(draft.projectPath), [draft.projectPath]);
  const projectIsTrusted = normalizedProjectPath.length > 0 && trustedProjectPaths.includes(normalizedProjectPath);

  async function handleAddAdditionalDirectory() {
    const picked = await window.doffice.pickDirectory();
    if (!picked) return;
    if (!draft.additionalDirs.includes(picked)) {
      onUpdateDraft({ additionalDirs: [...draft.additionalDirs, picked], additionalDirInput: picked });
    } else {
      onUpdateDraft({ additionalDirInput: picked });
    }
  }

  function commitAdditionalDirInput() {
    const next = draft.additionalDirInput.trim();
    if (!next || draft.additionalDirs.includes(next)) return;
    onUpdateDraft({ additionalDirs: [...draft.additionalDirs, next], additionalDirInput: next });
  }

  async function submitIfTrusted() {
    if (!draft.projectPath.trim()) return;
    await onSubmit();
  }

  async function handleFormSubmit(event: FormEvent) {
    event.preventDefault();
    if (!draft.projectPath.trim()) return;
    if (!projectIsTrusted) {
      setShowTrustPrompt(true);
      return;
    }
    await submitIfTrusted();
  }

  async function approveTrustAndSubmit() {
    if (!normalizedProjectPath) return;
    setTrustedProjectPaths((current) => (current.includes(normalizedProjectPath) ? current : [...current, normalizedProjectPath]));
    setShowTrustPrompt(false);
    await submitIfTrusted();
  }

  function providerCard(provider: "claude" | "codex" | "gemini", label: string, icon: string, tone: string, subtitle: string) {
    const active = draft.provider === provider;
    return (
      <button
        type="button"
        className={`execution-choice-card tone-${tone} ${active ? "is-active" : ""}`}
        onClick={() =>
          onUpdateDraft({
            provider,
            selectedModel: provider === "codex" ? "gpt-5.4" : provider === "gemini" ? "gemini-2.5-pro" : "sonnet"
          })
        }
      >
        <strong><span className="sheet-inline-icon">{icon}</span>{label}</strong>
        <span>{subtitle}</span>
        {active ? <span className="execution-check">●</span> : null}
      </button>
    );
  }

  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <div className="sheet-card session-sheet-card" onClick={(event) => event.stopPropagation()}>
        <div className="sheet-header">
          <div className="sheet-title-block">
            <strong><span className="sheet-title-icon tone-blue">＋</span>{t("session.new")}</strong>
            <div className="sheet-subtitle">{t("custom.new.session.subtitle")}</div>
          </div>
          <button className="chrome-icon-button" onClick={onClose}>
            ✕
          </button>
        </div>

        <form className="sheet-form session-sheet-form" onSubmit={handleFormSubmit}>
          <div className="session-sheet-grid">
            <div className="session-sheet-main">
              <section className="session-config-section">
                <div className="panel-header">
                  <span>빠른 시작</span>
                </div>
                <div className="quick-start-shell">
                  <button type="button" className="quick-start-resume-card compact" onClick={() => onApplyPreset("balanced")}>
                    <strong><span className="sheet-inline-icon">↺</span>마지막 설정 불러오기</strong>
                    <span>빠른 프리셋과 마지막 실행값을 바로 적용합니다.</span>
                  </button>
                  <div className="preset-grid">
                    {presets.map((preset) => (
                      <button
                        key={preset.id}
                        type="button"
                        className={`preset-card tone-${preset.tone}`}
                        onClick={() => onApplyPreset(preset.id)}
                      >
                        <div className="preset-card-symbol">{preset.symbol}</div>
                        <strong>{t(preset.title)}</strong>
                        <span>{t(preset.subtitle)}</span>
                      </button>
                    ))}
                  </div>

                  {favoriteProjects.length > 0 ? (
                    <>
                      <div className="panel-header recent-projects-heading">
                        <span>즐겨찾기 프로젝트</span>
                      </div>
                      <div className="quick-start-recent-strip">
                        {favoriteProjects.slice(0, 4).map((project) => (
                          <button key={project.path} type="button" className="quick-project-card" onClick={() => onChooseProject(project)}>
                            <strong><span className="sheet-inline-icon tone-yellow">★</span>{project.name}</strong>
                            <span className="path-ellipsis">{project.path}</span>
                          </button>
                        ))}
                      </div>
                    </>
                  ) : null}

                  {recentProjects.length > 0 ? (
                    <>
                      <div className="panel-header recent-projects-heading">
                        <span>최근 프로젝트</span>
                      </div>
                      <div className="quick-start-recent-strip">
                        {recentProjects.slice(0, 6).map((project) => (
                          <button key={project.path} type="button" className="quick-project-card" onClick={() => onChooseProject(project)}>
                            <strong><span className="sheet-inline-icon tone-blue">📁</span>{project.name}</strong>
                            <span className="path-ellipsis">{project.path}</span>
                            <small>{relativeTime(project.lastUsedAt)}</small>
                          </button>
                        ))}
                      </div>
                    </>
                  ) : null}
                </div>
              </section>

              <section className="session-config-section">
                <div className="panel-header">
                  <span>{t("terminal.config.project")}</span>
                </div>
                <label className="sheet-field">
                  <span>{t("custom.project.path")}</span>
                  <div className="path-field-row">
                    <input
                      value={draft.projectPath}
                      onChange={(event) => onUpdateDraft({ projectPath: event.target.value })}
                      placeholder="C:\\project"
                    />
                    <button type="button" className="secondary-button" onClick={onPickDirectory}>
                      {t("custom.browse")}
                    </button>
                    <button
                      type="button"
                      className={`favorite-toggle-button ${isFavorite ? "is-active" : ""}`}
                      onClick={onToggleFavorite}
                      disabled={!draft.projectPath.trim()}
                    >
                      {isFavorite ? "★" : "☆"}
                    </button>
                  </div>
                </label>
                <label className="sheet-field">
                  <span>{t("custom.display.name")}</span>
                  <input
                    value={draft.projectName}
                    onChange={(event) => onUpdateDraft({ projectName: event.target.value })}
                    placeholder={t("custom.project.name.placeholder")}
                  />
                </label>
              </section>

              <section className="session-config-section">
                <div className="panel-header">
                  <span>{t("custom.initial.prompt")}</span>
                </div>
                <label className="sheet-field">
                  <textarea
                    rows={4}
                    value={draft.initialPrompt}
                    onChange={(event) => onUpdateDraft({ initialPrompt: event.target.value })}
                    placeholder={t("custom.initial.prompt.placeholder")}
                  />
                </label>
              </section>

              <section className="session-config-section">
                <div className="panel-header">
                  <span>실행 설정</span>
                </div>
                <div className="execution-settings-stack">
                  <div className="execution-subhead">Agent</div>
                  <div className="execution-choice-grid three">
                    {providerCard("claude", "Claude", "💬", "blue", "Claude Code CLI")}
                    {providerCard("codex", "Codex", "⌘", "orange", "Codex CLI")}
                    {providerCard("gemini", "Gemini", "✦", "green", "Gemini CLI")}
                  </div>

                  {draft.provider === "claude" ? (
                    <>
                      <div className="execution-subhead">모델</div>
                      <div className="execution-choice-grid three">
                        {claudeModels.map((model) => (
                          <button
                            key={model.value}
                            type="button"
                            className={`execution-choice-card tone-${model.tone} ${draft.selectedModel === model.value ? "is-active" : ""}`}
                            onClick={() => onUpdateDraft({ selectedModel: model.value })}
                          >
                            <strong><span className="sheet-inline-icon">{model.icon}</span>{model.label}</strong>
                            {draft.selectedModel === model.value ? <span className="execution-check">●</span> : null}
                          </button>
                        ))}
                      </div>

                      <div className="execution-subhead">Effort</div>
                      <div className="execution-choice-grid four">
                        {claudeEfforts.map((option) => (
                          <button
                            key={option.value}
                            type="button"
                            className={`execution-choice-card tone-${option.tone} ${draft.effortLevel === option.value ? "is-active" : ""}`}
                            onClick={() => onUpdateDraft({ effortLevel: option.value })}
                          >
                            <strong><span className="sheet-inline-icon">{option.icon}</span>{option.label}</strong>
                            {draft.effortLevel === option.value ? <span className="execution-check">●</span> : null}
                          </button>
                        ))}
                      </div>

                      <div className="execution-subhead">권한</div>
                      <div className="execution-choice-grid two">
                        {claudePermissions.map((option) => (
                          <button
                            key={option.value}
                            type="button"
                            className={`execution-choice-card tone-${option.tone} ${draft.permissionMode === option.value ? "is-active" : ""}`}
                            onClick={() => onUpdateDraft({ permissionMode: option.value })}
                          >
                            <strong><span className="sheet-inline-icon">{option.icon}</span>{option.label}</strong>
                            <span>{option.subtitle}</span>
                            {draft.permissionMode === option.value ? <span className="execution-check">●</span> : null}
                          </button>
                        ))}
                      </div>
                    </>
                  ) : draft.provider === "codex" ? (
                    <>
                      <div className="session-option-grid codex-execution-grid">
                        <label className="sheet-field">
                          <span>모델</span>
                          <select value={draft.selectedModel} onChange={(event) => onUpdateDraft({ selectedModel: event.target.value })}>
                            {codexModels.map((model) => (
                              <option key={model.value} value={model.value}>
                                {model.label}
                              </option>
                            ))}
                          </select>
                        </label>
                      </div>

                      <div className="execution-subhead">Sandbox</div>
                      <div className="execution-choice-grid three">
                        {codexSandboxes.map((option) => (
                          <button
                            key={option.value}
                            type="button"
                            className={`execution-choice-card tone-${option.tone} ${draft.codexSandboxMode === option.value ? "is-active" : ""}`}
                            onClick={() => onUpdateDraft({ codexSandboxMode: option.value as NewSessionDraftState["codexSandboxMode"] })}
                          >
                            <strong><span className="sheet-inline-icon">{option.icon}</span>{option.label}</strong>
                            {draft.codexSandboxMode === option.value ? <span className="execution-check">●</span> : null}
                          </button>
                        ))}
                      </div>

                      <div className="execution-subhead">Approval</div>
                      <div className="execution-choice-grid three">
                        {codexApprovals.map((option) => (
                          <button
                            key={option.value}
                            type="button"
                            className={`execution-choice-card tone-${option.tone} ${draft.codexApprovalPolicy === option.value ? "is-active" : ""}`}
                            onClick={() => onUpdateDraft({ codexApprovalPolicy: option.value as NewSessionDraftState["codexApprovalPolicy"] })}
                          >
                            <strong><span className="sheet-inline-icon">{option.icon}</span>{option.label}</strong>
                            {draft.codexApprovalPolicy === option.value ? <span className="execution-check">●</span> : null}
                          </button>
                        ))}
                      </div>
                    </>
                  ) : (
                    <div className="session-option-grid codex-execution-grid">
                      <label className="sheet-field">
                        <span>모델</span>
                        <select value={draft.selectedModel} onChange={(event) => onUpdateDraft({ selectedModel: event.target.value })}>
                          {geminiModels.map((model) => (
                            <option key={model.value} value={model.value}>
                              {model.label}
                            </option>
                          ))}
                        </select>
                      </label>
                    </div>
                  )}
                </div>
              </section>

              <section className="session-config-section">
                <div className="panel-header">
                  <span>터미널</span>
                  <strong className="terminal-count-label">{`${draft.terminalCount}개`}</strong>
                </div>
                <div className="terminal-count-grid">
                  {terminalCounts.map((count) => (
                    <button
                      key={count}
                      type="button"
                      className={`terminal-count-card ${draft.terminalCount === count ? "is-active" : ""}`}
                      onClick={() => onUpdateDraft({ terminalCount: count })}
                    >
                      <span className={`terminal-count-pixels count-${count}`}>
                        {Array.from({ length: count }).map((_, index) => (
                          <span key={`${count}-${index}`} />
                        ))}
                      </span>
                      <strong>{count}</strong>
                    </button>
                  ))}
                </div>
              </section>

              <section className="session-config-section">
                <button
                  type="button"
                  className="advanced-toggle-row"
                  onClick={() => onUpdateDraft({ advancedExpanded: !draft.advancedExpanded })}
                >
                  <strong>{draft.advancedExpanded ? "⌄" : "›"} 고급 옵션</strong>
                  <span>예산, 워크트리, 도구 제한 같은 세부 옵션</span>
                </button>
              </section>

              {draft.advancedExpanded ? (
                <section className="session-config-section">
                  <div className="advanced-options-stack">
                    <label className="sheet-field">
                      <span><span className="sheet-inline-icon tone-purple">💬</span>시스템 프롬포트</span>
                      <textarea
                        rows={3}
                        value={draft.systemPrompt}
                        onChange={(event) => onUpdateDraft({ systemPrompt: event.target.value })}
                        placeholder="추가 지시사항 (--append-system-prompt)"
                      />
                    </label>

                    <div className="advanced-inline-grid">
                      <label className="sheet-field">
                        <span><span className="sheet-inline-icon tone-yellow">🪙</span>예산 한도 (USD)</span>
                        <input value={draft.maxBudget} onChange={(event) => onUpdateDraft({ maxBudget: event.target.value })} placeholder="0 = 무제한" />
                      </label>
                      <label className="sheet-toggle advanced-toggle-pill">
                        <span><span className="sheet-inline-icon tone-blue">↪</span>이전 대화 이어하기</span>
                        <input
                          type="checkbox"
                          checked={draft.continueSession}
                          onChange={(event) => onUpdateDraft({ continueSession: event.target.checked })}
                        />
                      </label>
                    </div>

                    <label className="sheet-toggle advanced-toggle-pill wide">
                      <span><span className="sheet-inline-icon tone-green">⑂</span>Git 워크트리 생성 <small>--worktree</small></span>
                      <input
                        type="checkbox"
                        checked={draft.useWorktree}
                        onChange={(event) => onUpdateDraft({ useWorktree: event.target.checked })}
                      />
                    </label>

                    <label className="sheet-field">
                      <span><span className="sheet-inline-icon tone-orange">🛠</span>허용 도구 (쉼표 구분)</span>
                      <input value={draft.allowedTools} onChange={(event) => onUpdateDraft({ allowedTools: event.target.value })} placeholder="예: Bash,Read,Edit,Write" />
                    </label>

                    <label className="sheet-field">
                      <span><span className="sheet-inline-icon tone-red">🛡✕</span>차단 도구 (쉼표 구분)</span>
                      <input value={draft.disallowedTools} onChange={(event) => onUpdateDraft({ disallowedTools: event.target.value })} placeholder="예: Bash(rm:*)" />
                    </label>

                    <label className="sheet-field">
                      <span><span className="sheet-inline-icon tone-blue">📁＋</span>추가 디렉토리 접근</span>
                      <div className="path-field-row">
                        <input
                          value={draft.additionalDirInput}
                          onChange={(event) => onUpdateDraft({ additionalDirInput: event.target.value })}
                          onBlur={commitAdditionalDirInput}
                          placeholder="경로 추가"
                        />
                        <button type="button" className="secondary-button icon-only-button" onClick={() => void handleAddAdditionalDirectory()}>
                          📁
                        </button>
                        <button type="button" className="secondary-button icon-only-button confirm-button" onClick={commitAdditionalDirInput}>
                          ＋
                        </button>
                      </div>
                    </label>

                    {draft.additionalDirs.length > 0 ? (
                      <div className="project-suggestion-list">
                        {draft.additionalDirs.map((directory) => (
                          <div key={directory} className="project-suggestion-row">
                            <div>
                              <strong>추가 경로</strong>
                              <span className="path-ellipsis">{directory}</span>
                            </div>
                            <button type="button" className="secondary-button" onClick={() => onUpdateDraft({ additionalDirs: draft.additionalDirs.filter((item) => item !== directory) })}>
                              제거
                            </button>
                          </div>
                        ))}
                      </div>
                    ) : null}
                  </div>
                </section>
              ) : null}
            </div>
          </div>

          <div className="sheet-actions">
            <button type="button" className="secondary-button" onClick={onClose}>
              {t("cancel")}
            </button>
            <button type="button" className="secondary-button" onClick={onAddPluginDirectory}>
              ⌁ 프리셋 저장
            </button>
            <button type="submit" className="primary-button" disabled={busy || !draft.projectPath.trim()}>
              ▶ Create
            </button>
          </div>
        </form>
      </div>

      {showTrustPrompt ? (
        <div className="sheet-floating-overlay" onClick={() => setShowTrustPrompt(false)}>
          <div className="sheet-card trust-prompt-card" onClick={(event) => event.stopPropagation()}>
            <div className="sheet-title-block">
              <strong><span className="sheet-title-icon tone-warning">🛡</span>프로젝트 신뢰 확인</strong>
              <div className="sheet-subtitle">처음 여는 폴더는 한 번 신뢰 여부를 확인합니다.</div>
            </div>
            <div className="trust-path-chip">{draft.projectPath.trim()}</div>
            <div className="trust-copy-stack">
              <strong>이 폴더를 신뢰하고 세션을 시작할까요?</strong>
              <span>에이전트는 이 프로젝트 안에서 Git 작업, 파일 수정, 터미널 명령 실행을 수행할 수 있습니다.</span>
              <span>직접 만든 프로젝트거나 검토를 끝낸 경로만 신뢰하는 편이 안전합니다.</span>
            </div>
            <div className="trust-action-row">
              <button type="button" className="mini-action-button" onClick={() => setShowTrustPrompt(false)} disabled={busy}>
                돌아가기
              </button>
              <button type="button" className="mini-action-button success trust-continue-button" onClick={() => void approveTrustAndSubmit()} disabled={busy}>
                신뢰하고 시작
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
