import { useState, useEffect } from "react";
import {
  AppWindow,
  Bell,
  ChevronRight,
  Download,
  EyeOff,
  FileImage,
  FolderOpen,
  LockKeyhole,
  MousePointer2,
  Move,
  Palette,
  PawPrint,
  ShieldCheck,
  Sparkles,
  WandSparkles
} from "lucide-react";

import appMetadata from "../../metadata/app.json";
import locale from "../../metadata/locales/en-US.json";
import { TermsPage, PrivacyPage } from "./LegalPages";

const app = appMetadata.product;
const links = appMetadata.links;
const home = locale.website.home;
const desktopPetSection = locale.website.sections.find((section) => section.id === "desktop-pet");

const navItems = [
  { label: "Features", href: "#features" },
  { label: "Desktop Pet", href: "#desktop-pet" },
  { label: "Privacy", href: "#privacy" },
  { label: "Support", href: "#support" }
];

const workflowSteps = [
  {
    title: "Drop images",
    body: "Add JPG, PNG, HEIC, and WebP files from Finder or the main window.",
    image: "/workflow/drop-images.svg"
  },
  {
    title: "Choose output",
    body: "Pick a preset, output format, resize limit, and metadata behavior.",
    image: "/workflow/choose-output.svg"
  },
  {
    title: "Compress locally",
    body: "ImagePet works on your Mac with sandboxed, user-selected access.",
    image: "/workflow/compress-locally.svg"
  },
  {
    title: "Review results",
    body: "See per-file status, saved space, and reveal completed files in Finder.",
    image: "/workflow/review-results.svg"
  }
];

const helperItems = [
  {
    title: "Finder Quick Action",
    body: "Start compression from Finder for supported image selections.",
    icon: MousePointer2
  },
  {
    title: "Shortcuts",
    body: "Use ImagePet from the Shortcuts app for repeatable local workflows.",
    icon: WandSparkles
  },
  {
    title: "Folder Watching",
    body: "Watch authorized folders and keep output access scoped to your choices.",
    icon: FolderOpen
  },
  {
    title: "Local notifications",
    body: "Get completion and attention-needed alerts without remote services.",
    icon: Bell
  }
];

const privacyItems = [
  { label: "No account", icon: EyeOff },
  { label: "No cloud upload", icon: ShieldCheck },
  { label: "No tracking", icon: LockKeyhole },
  { label: "User-selected folders", icon: FolderOpen }
];

const petDetails = [
  {
    title: "Progress companion",
    body: "The pet reflects queued, compressing, completed, and attention-needed states.",
    icon: PawPrint
  },
  {
    title: "Desktop presence",
    body: "Keep compression status visible without keeping the main window in front.",
    icon: Move
  },
  {
    title: "Built-in themes",
    body: "Choose Dog, Cat, Rabbit, Hamster, Squirrel, or Pufferfish.",
    icon: Palette
  }
];

const petThemes = [
  {
    name: "Dog",
    description: "Friendly all-round puppy",
    image: "/pets/dog.png"
  },
  {
    name: "Pufferfish",
    description: "Soft floating pacing",
    image: "/pets/pufferfish.png"
  },
  {
    name: "Squirrel",
    description: "Quick-tailed motion",
    image: "/pets/squirrel.png"
  },
  {
    name: "Hamster",
    description: "Cozy and compact",
    image: "/pets/hamster.png"
  },
  {
    name: "Cat",
    description: "Warm orange idle",
    image: "/pets/cat.png"
  },
  {
    name: "Rabbit",
    description: "Light springy movement",
    image: "/pets/rabbit.png"
  }
];

function metadataLink(value: string | null, fallback: string) {
  return value ?? fallback;
}

function App() {
  const [activePetIndex, setActivePetIndex] = useState(0);
  const [path, setPath] = useState(window.location.pathname);

  useEffect(() => {
    const handlePopState = () => {
      setPath(window.location.pathname);
    };
    window.addEventListener("popstate", handlePopState);
    return () => window.removeEventListener("popstate", handlePopState);
  }, []);

  const navigateTo = (newPath: string) => {
    window.history.pushState({}, "", newPath);
    setPath(newPath);
    window.scrollTo(0, 0);
  };

  const appStoreHref = metadataLink(links.macAppStore, "#download");
  const privacyHref = metadataLink(links.privacyPolicy, "#privacy");
  const supportHref = (() => {
    if (!links.support) return "mailto:";
    if (links.support.includes("github.com") && links.support.includes("/issues")) {
      const base = links.support.endsWith("/new") ? links.support : `${links.support.replace(/\/+$/, "")}/new`;
      const title = encodeURIComponent("[Support] ");
      const body = encodeURIComponent(
        "**macOS Version:** \n" +
        "**ImagePet Version:** \n" +
        "**Input Format:** \n" +
        "**Output Format:** \n\n" +
        "**Description of what happened:** \n"
      );
      return `${base}?title=${title}&body=${body}`;
    }
    return links.support;
  })();

  if (path === "/en/terms" || path === "/en/terms/") {
    return (
      <TermsPage 
        activePetIndex={activePetIndex} 
        setActivePetIndex={setActivePetIndex} 
        petThemes={petThemes}
        onBack={() => navigateTo("/")}
      />
    );
  }

  if (path === "/en/privacy" || path === "/en/privacy/") {
    return (
      <PrivacyPage 
        activePetIndex={activePetIndex} 
        setActivePetIndex={setActivePetIndex} 
        petThemes={petThemes}
        onBack={() => navigateTo("/")}
      />
    );
  }

  return (
    <main className="site-shell">
      <header className="site-header" aria-label="Primary navigation">
        <a className="brand" href="#top" aria-label="ImagePet home">
          <img src="/imagepet-icon.png" alt="" className="brand-icon" />
          <span>{app.name}</span>
        </a>
        <nav className="nav-links">
          {navItems.map((item) => (
            <a href={item.href} key={item.label}>
              {item.label}
            </a>
          ))}
        </nav>
        <a
          className="header-cta"
          href={appStoreHref}
          aria-disabled={!links.macAppStore}
          onClick={(event) => {
            if (!links.macAppStore) {
              event.preventDefault();
              document.getElementById("download")?.scrollIntoView({ behavior: "smooth" });
            }
          }}
        >
          <Download size={16} aria-hidden="true" />
          Download
        </a>
      </header>

      <section className="hero-section" id="top">
        <div className="hero-copy">
          <h1>{home.heroTitle}</h1>
          <p>{home.heroSubtitle}</p>
          <div className="hero-actions" id="download">
            <a
              className="primary-button"
              href={appStoreHref}
              aria-disabled={!links.macAppStore}
              onClick={(event) => {
                if (!links.macAppStore) {
                  event.preventDefault();
                }
              }}
            >
              <Download size={18} aria-hidden="true" />
              {home.primaryCtaLabel}
            </a>
            <a className="secondary-button" href={privacyHref}>
              {home.secondaryCtaLabel}
              <ChevronRight size={17} aria-hidden="true" />
            </a>
          </div>
          {!links.macAppStore && (
            <p className="availability-note">
              Mac App Store link will be added after the first approved release.
            </p>
          )}
        </div>

        <div className="hero-visual" aria-label="ImagePet app workflow preview">
          <ProductMockup />
        </div>
      </section>

      <section className="format-strip" aria-label="Supported formats">
        <span>Inputs</span>
        <strong>{appMetadata.capabilities.inputFormats.join(" / ")}</strong>
        <span>Outputs</span>
        <strong>{appMetadata.capabilities.outputFormats.join(" / ")}</strong>
      </section>

      <section className="workflow-section" id="features">
        <div className="section-heading">
          <h2>Simple, local, and made for Mac.</h2>
          <p>{locale.website.sections[1].body}</p>
        </div>
        <div className="workflow-rail">
          {workflowSteps.map((item, index) => (
            <article className="workflow-step" key={item.title}>
              <div className="workflow-illustration">
                <img src={item.image} alt="" loading="lazy" />
                <span className="step-number">{String(index + 1).padStart(2, "0")}</span>
              </div>
              <h3>{item.title}</h3>
              <p>{item.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="helpers-section">
        <div className="helpers-copy">
          <h2>{locale.website.sections[2].heading}</h2>
          <p>{locale.website.sections[2].body}</p>
        </div>
        <div className="helpers-grid">
          {helperItems.map((item) => (
            <article className="helper-item" key={item.title}>
              <item.icon size={22} strokeWidth={1.8} aria-hidden="true" />
              <div>
                <h3>{item.title}</h3>
                <p>{item.body}</p>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="desktop-pet-section" id="desktop-pet">
        <div className="desktop-pet-copy">
          <h2>{desktopPetSection?.heading ?? "A desktop pet that keeps progress visible"}</h2>
          <p>
            {desktopPetSection?.body ??
              "ImagePet can keep a small companion on your desktop, reflect compression state, and make local batch work easier to notice."}
          </p>
          <div className="pet-count">6 built-in desktop pets</div>
        </div>
        <div className="desktop-pet-stage" aria-label="Desktop pet feature preview">
          <div className="desktop-pet-window">
            <div className="pet-titlebar">
              <span />
              <strong>Built-in Desktop Pets</strong>
            </div>
            <div className="pet-showcase-grid">
              {petThemes.map((theme) => (
                <article key={theme.name} className="pet-theme-card">
                  <img src={theme.image} alt={`ImagePet desktop pet ${theme.name} theme`} />
                  <strong>{theme.name}</strong>
                  <span>{theme.description}</span>
                </article>
              ))}
            </div>
          </div>
          <div className="pet-detail-list">
            {petDetails.map((item) => (
              <article key={item.title}>
                <item.icon size={21} strokeWidth={1.8} aria-hidden="true" />
                <div>
                  <h3>{item.title}</h3>
                  <p>{item.body}</p>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="privacy-support-section" id="privacy">
        <div className="privacy-panel">
          <div className="privacy-copy">
            <h2>Private by default.</h2>
            <p>{locale.website.privacy.summary}</p>
          </div>
          <div className="privacy-list">
            {privacyItems.map((item) => (
              <span key={item.label}>
                <item.icon size={18} strokeWidth={1.9} aria-hidden="true" />
                {item.label}
              </span>
            ))}
          </div>
        </div>

        <div className="support-panel" id="support">
          <h2>{locale.website.support.title}</h2>
          <p>{locale.website.support.summary}</p>
          <a className="support-link" href={supportHref} target="_blank" rel="noreferrer">
            Open Support Issues on GitHub
          </a>
        </div>
      </section>

      <footer className="site-footer">
        <a className="footer-brand" href="#top">
          <img src="/imagepet-icon.png" alt="" />
          <span>{app.name}</span>
        </a>
        <div className="footer-links">
          <a 
            href="/en/terms" 
            onClick={(e) => {
              e.preventDefault();
              navigateTo("/en/terms");
            }}
          >
            Terms
          </a>
          <a 
            href="/en/privacy" 
            onClick={(e) => {
              e.preventDefault();
              navigateTo("/en/privacy");
            }}
          >
            Privacy
          </a>
          <a href="#support">Support</a>
          <a href={appStoreHref} aria-disabled={!links.macAppStore}>
            App Store
          </a>
          <a href="https://github.com/gewill/ImagePet" target="_blank" rel="noreferrer">
            GitHub
          </a>
        </div>
      </footer>

      {/* Floating Interactive Desktop Pet Mini */}
      <div 
        className="floating-desktop-pet"
        onClick={() => setActivePetIndex((prev) => (prev + 1) % petThemes.length)}
      >
        <div className="floating-pet-tooltip">
          <strong>Desktop Pet: {petThemes[activePetIndex].name}</strong>
          <span>{petThemes[activePetIndex].description}</span>
          <span className="tooltip-hint">Click to switch theme</span>
        </div>
        <div className="floating-pet-card">
          <img 
            src={petThemes[activePetIndex].image} 
            alt={`ImagePet desktop pet ${petThemes[activePetIndex].name} theme`} 
            key={activePetIndex}
            className="floating-pet-img"
          />
        </div>
      </div>
    </main>
  );
}

function ProductMockup() {
  return (
    <div className="product-window">
      <div className="window-toolbar">
        <div className="traffic-lights" aria-hidden="true">
          <span />
          <span />
          <span />
        </div>
        <div className="toolbar-title">
          <AppWindow size={15} aria-hidden="true" />
          Compression Queue
        </div>
      </div>
      <div className="mockup-body">
        <div className="drop-zone">
          <Sparkles size={26} strokeWidth={1.8} aria-hidden="true" />
          <strong>Drop images here</strong>
          <span>Compress locally to smaller files</span>
        </div>
        <div className="queue-list">
          <QueueRow name="vacation.heic" format="HEIC to JPEG" state="Saved 64%" />
          <QueueRow name="studio.png" format="PNG to WebP" state="Saved 48%" />
          <QueueRow name="banner.jpg" format="JPEG optimized" state="Ready" />
        </div>
        <div className="pet-companion" aria-label="Desktop pet progress companion">
          <img src="/desktop-pet-dog.png" alt="" />
          <div>
            <strong>Desktop Pet is watching</strong>
            <span>2 files compressed</span>
          </div>
        </div>
      </div>
    </div>
  );
}

function QueueRow({ name, format, state }: { name: string; format: string; state: string }) {
  return (
    <div className="queue-row">
      <div className="file-thumb">
        <FileImage size={18} aria-hidden="true" />
      </div>
      <div>
        <strong>{name}</strong>
        <span>{format}</span>
      </div>
      <em>{state}</em>
    </div>
  );
}

export default App;
