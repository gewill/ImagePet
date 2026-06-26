import { Download } from "lucide-react";

interface NavItem {
  label: string;
  href: string;
}

interface SiteHeaderProps {
  currentPath: string;
  navigateTo: (path: string) => void;
  navItems: NavItem[];
  appStoreHref: string;
  hasMacAppStore: boolean;
  appName: string;
}

function isActive(href: string, currentPath: string): boolean {
  if (href.startsWith("/")) {
    return currentPath === href || currentPath === href + "/";
  }
  return false;
}

export function SiteHeader({
  currentPath,
  navigateTo,
  navItems,
  appStoreHref,
  hasMacAppStore,
  appName
}: SiteHeaderProps) {
  return (
    <header className="site-header" aria-label="Primary navigation">
      <a
        className="brand"
        href="/"
        onClick={(e) => {
          e.preventDefault();
          navigateTo("/");
        }}
        aria-label="ImagePet home"
      >
        <img src="/imagepet-icon.png" alt="" className="brand-icon" />
        <span>{appName}</span>
      </a>
      <nav className="nav-links">
        {navItems.map((item) => (
          <a
            href={item.href}
            key={item.label}
            className={isActive(item.href, currentPath) ? "nav-active" : ""}
            onClick={(event) => {
              if (item.href.startsWith("/")) {
                event.preventDefault();
                navigateTo(item.href);
              }
            }}
          >
            {item.label}
          </a>
        ))}
      </nav>
      <a
        className="header-cta"
        href={appStoreHref}
        aria-disabled={!hasMacAppStore}
        onClick={(event) => {
          if (!hasMacAppStore) {
            event.preventDefault();
          }
        }}
      >
        <Download size={16} aria-hidden="true" />
        Download
      </a>
    </header>
  );
}
