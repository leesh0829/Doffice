import { useEffect, useMemo, useState, type ReactNode } from "react";
import { t } from "./localizationCatalog";

interface OnboardingOverlayProps {
  isOpen: boolean;
  onSkip: () => void;
  onFinish: () => void;
}

type StepTone = "accent" | "green" | "purple" | "orange" | "cyan" | "pink" | "yellow";

function FeatureCard(props: { icon: string; title: string; description: string; tone: StepTone }) {
  return (
    <div className={`onboarding-card tone-${props.tone}`}>
      <strong>
        <span>{props.icon}</span>
        <span>{props.title}</span>
      </strong>
      <span>{props.description}</span>
    </div>
  );
}

function ShortcutCard(props: { shortcut: string; label: string }) {
  return (
    <div className="onboarding-shortcut-card">
      <strong>{props.shortcut}</strong>
      <span>{props.label}</span>
    </div>
  );
}

function ToolList(props: { children: ReactNode }) {
  return <div className="onboarding-tool-list">{props.children}</div>;
}

export function OnboardingOverlay(props: OnboardingOverlayProps) {
  const { isOpen, onSkip, onFinish } = props;
  const [currentStep, setCurrentStep] = useState(0);

  useEffect(() => {
    if (!isOpen) {
      setCurrentStep(0);
    }
  }, [isOpen]);

  const totalSteps = 8;
  const isLastStep = currentStep === totalSteps - 1;

  useEffect(() => {
    if (!isOpen) return;
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        onSkip();
        return;
      }
      if (event.key === "Enter") {
        event.preventDefault();
        if (isLastStep) {
          onFinish();
          return;
        }
        setCurrentStep((value) => Math.min(value + 1, totalSteps - 1));
      }
    }

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [isLastStep, isOpen, onFinish, onSkip]);

  const stepBody = useMemo(() => {
    switch (currentStep) {
      case 0:
        return (
          <div className="onboarding-step-body is-centered">
            <div className="onboarding-hero">
              <div className="onboarding-hero-badge">⌘</div>
              <h2>{t("onboard.welcome.title")}</h2>
              <p>{t("onboard.welcome.subtitle")}</p>
            </div>
            <div className="onboarding-chip-row">
              <span className="onboarding-chip tone-accent">{t("onboard.welcome.visualization")}</span>
              <span className="onboarding-chip tone-green">{t("onboard.welcome.automation")}</span>
              <span className="onboarding-chip tone-purple">{t("onboard.welcome.collaboration")}</span>
            </div>
          </div>
        );
      case 1:
        return (
          <div className="onboarding-step-body">
            <div className="onboarding-step-header">
              <span className="onboarding-step-icon tone-green">⌘</span>
              <div>
                <h2>{t("onboard.session.title")}</h2>
                <p>{t("onboard.session.subtitle")}</p>
              </div>
            </div>
            <div className="onboarding-grid two-up">
              <FeatureCard icon="＋" title="Ctrl+T" description={t("onboard.session.new")} tone="green" />
              <FeatureCard icon="▣" title="Ctrl+1~9" description={t("onboard.session.switch")} tone="accent" />
              <FeatureCard icon="⌘" title="Ctrl+P" description={t("onboard.session.palette")} tone="cyan" />
              <FeatureCard icon="↻" title="Ctrl+R" description={t("onboard.session.refresh")} tone="orange" />
            </div>
          </div>
        );
      case 2:
        return (
          <div className="onboarding-step-body">
            <div className="onboarding-step-header">
              <span className="onboarding-step-icon tone-purple">🏢</span>
              <div>
                <h2>{t("onboard.office.title")}</h2>
                <p>{t("onboard.office.subtitle")}</p>
              </div>
            </div>
            <div className="onboarding-grid two-up">
              <FeatureCard icon="🗂" title={t("onboard.office.planner")} description={t("onboard.office.planner.desc")} tone="purple" />
              <FeatureCard icon="🔨" title={t("onboard.office.developer")} description={t("onboard.office.developer.desc")} tone="accent" />
              <FeatureCard icon="🛡" title={t("onboard.office.qa")} description={t("onboard.office.qa.desc")} tone="green" />
              <FeatureCard icon="📝" title={t("onboard.office.reporter")} description={t("onboard.office.reporter.desc")} tone="orange" />
            </div>
            <div className="onboarding-note">{t("onboard.office.note")}</div>
          </div>
        );
      case 3:
        return (
          <div className="onboarding-step-body">
            <div className="onboarding-step-header">
              <span className="onboarding-step-icon tone-orange">▥</span>
              <div>
                <h2>{t("onboard.view.title")}</h2>
                <p>{t("onboard.view.subtitle")}</p>
              </div>
            </div>
            <div className="onboarding-grid two-up">
              <FeatureCard icon="▥" title={t("view.split")} description={t("onboard.view.split")} tone="accent" />
              <FeatureCard icon="⌘" title={t("view.terminal")} description={t("onboard.view.terminal")} tone="green" />
              <FeatureCard icon="🏢" title={t("view.office")} description={t("onboard.view.office")} tone="purple" />
              <FeatureCard icon="☰" title={t("view.strip")} description={t("onboard.view.strip")} tone="orange" />
            </div>
          </div>
        );
      case 4:
        return (
          <div className="onboarding-step-body">
            <div className="onboarding-step-header">
              <span className="onboarding-step-icon tone-cyan">⑂</span>
              <div>
                <h2>{t("onboard.tools.title")}</h2>
                <p>{t("onboard.tools.subtitle")}</p>
              </div>
            </div>
            <div className="onboarding-grid two-up">
              <div className="onboarding-card tone-cyan">
                <strong>Git</strong>
                <ToolList>
                  <span>{t("onboard.tools.git.graph")}</span>
                  <span>{t("onboard.tools.git.commit")}</span>
                  <span>{t("onboard.tools.git.diff")}</span>
                </ToolList>
              </div>
              <div className="onboarding-card tone-accent">
                <strong>Browser</strong>
                <ToolList>
                  <span>{t("onboard.tools.browser.tabs")}</span>
                  <span>{t("onboard.tools.browser.search")}</span>
                  <span>{t("onboard.tools.browser.bookmarks")}</span>
                </ToolList>
              </div>
            </div>
          </div>
        );
      case 5:
        return (
          <div className="onboarding-step-body">
            <div className="onboarding-step-header">
              <span className="onboarding-step-icon tone-pink">🧩</span>
              <div>
                <h2>{t("onboard.plugins.title")}</h2>
                <p>{t("onboard.plugins.subtitle")}</p>
              </div>
            </div>
            <div className="onboarding-grid two-up">
              <FeatureCard icon="👥" title={t("onboard.plugins.characters.title")} description={t("onboard.plugins.characters.desc")} tone="purple" />
              <FeatureCard icon="🎨" title={t("onboard.plugins.themes.title")} description={t("onboard.plugins.themes.desc")} tone="accent" />
              <FeatureCard icon="🛋" title={t("onboard.plugins.furniture.title")} description={t("onboard.plugins.furniture.desc")} tone="orange" />
              <FeatureCard icon="🏆" title={t("onboard.plugins.achievements.title")} description={t("onboard.plugins.achievements.desc")} tone="yellow" />
            </div>
            <div className="onboarding-note">{t("onboard.plugins.note")}</div>
          </div>
        );
      case 6:
        return (
          <div className="onboarding-step-body">
            <div className="onboarding-step-header">
              <span className="onboarding-step-icon tone-cyan">⌨</span>
              <div>
                <h2>{t("onboard.shortcuts.title")}</h2>
                <p>{t("onboard.shortcuts.subtitle")}</p>
              </div>
            </div>
            <div className="onboarding-shortcut-grid">
              <ShortcutCard shortcut="Ctrl+T" label={t("onboard.shortcuts.new")} />
              <ShortcutCard shortcut="Ctrl+Delete" label={t("onboard.shortcuts.close")} />
              <ShortcutCard shortcut="Ctrl+P" label={t("onboard.shortcuts.palette")} />
              <ShortcutCard shortcut="Ctrl+J" label={t("onboard.shortcuts.center")} />
              <ShortcutCard shortcut="Ctrl+R" label={t("onboard.shortcuts.refresh")} />
              <ShortcutCard shortcut="Ctrl+Backspace" label={t("onboard.shortcuts.deny")} />
              <ShortcutCard shortcut="Ctrl+Enter" label={t("onboard.shortcuts.approve")} />
              <ShortcutCard shortcut="Ctrl+1~9" label={t("onboard.shortcuts.switch")} />
            </div>
          </div>
        );
      default:
        return (
          <div className="onboarding-step-body is-centered">
            <div className="onboarding-hero">
              <div className="onboarding-hero-badge tone-yellow">✦</div>
              <h2>{t("onboard.ready.title")}</h2>
              <p>{t("onboard.ready.subtitle")}</p>
            </div>
            <div className="onboarding-grid one-up">
              <FeatureCard icon="⚙" title={t("onboard.ready.tip.settings.title")} description={t("onboard.ready.tip.settings.desc")} tone="accent" />
              <FeatureCard icon="🎨" title={t("onboard.ready.tip.theme.title")} description={t("onboard.ready.tip.theme.desc")} tone="purple" />
              <FeatureCard icon="🏆" title={t("onboard.ready.tip.progress.title")} description={t("onboard.ready.tip.progress.desc")} tone="yellow" />
            </div>
          </div>
        );
    }
  }, [currentStep]);

  if (!isOpen) return null;

  return (
    <div className="overlay-backdrop onboarding-backdrop" onClick={onSkip}>
      <div className="onboarding-modal" onClick={(event) => event.stopPropagation()}>
        <div className="onboarding-topbar">
          <div className="onboarding-progress">
            {Array.from({ length: totalSteps }, (_, index) => (
              <span key={index} className={`onboarding-progress-dot ${index === currentStep ? "is-active" : ""}`} />
            ))}
          </div>
          <div className="onboarding-topbar-actions">
            <span>{`${currentStep + 1}/${totalSteps}`}</span>
            <button type="button" className="mini-action-button" onClick={onSkip}>
              {t("onboard.skip")}
            </button>
          </div>
        </div>

        <div className="onboarding-body">{stepBody}</div>

        <div className="onboarding-footer">
          <button
            type="button"
            className="mini-action-button"
            onClick={() => setCurrentStep((value) => Math.max(value - 1, 0))}
            disabled={currentStep === 0}
          >
            {t("onboard.previous")}
          </button>
          <div className="onboarding-footer-spacer" />
          {!isLastStep ? (
            <button type="button" className="mini-action-button install-button" onClick={() => setCurrentStep((value) => Math.min(value + 1, totalSteps - 1))}>
              {t("onboard.next")}
            </button>
          ) : (
            <button type="button" className="mini-action-button install-button" onClick={onFinish}>
              {t("onboard.start")}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
