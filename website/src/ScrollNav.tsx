import { useState, useEffect, useCallback } from "react";

const sections = [
  { id: "features", label: "Features" },
  { id: "desktop-pet", label: "Desktop Pet" },
  { id: "privacy", label: "Privacy" },
  { id: "support", label: "Support" }
];

export function ScrollNav() {
  const [activeIndex, setActiveIndex] = useState(0);

  const scrollTo = useCallback((index: number) => {
    const el = document.getElementById(sections[index].id);
    if (el) {
      el.scrollIntoView({ behavior: "smooth" });
    }
  }, []);

  useEffect(() => {
    const els = sections
      .map((s) => document.getElementById(s.id))
      .filter(Boolean) as HTMLElement[];

    if (els.length === 0) return;

    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => {
            const ai = sections.findIndex((s) => s.id === a.target.id);
            const bi = sections.findIndex((s) => s.id === b.target.id);
            return ai - bi;
          });

        if (visible.length > 0) {
          const idx = sections.findIndex((s) => s.id === visible[0].target.id);
          if (idx !== -1) setActiveIndex(idx);
        }
      },
      { threshold: 0.3, rootMargin: "-80px 0px -40% 0px" }
    );

    els.forEach((el) => observer.observe(el));
    return () => observer.disconnect();
  }, []);

  return (
    <nav className="scroll-nav" aria-label="Page sections">
      <div className="scroll-nav-track">
        {sections.map((s, i) => (
          <button
            key={s.id}
            type="button"
            className={`scroll-nav-dot${i === activeIndex ? " active" : ""}`}
            onClick={() => scrollTo(i)}
            aria-label={`Scroll to ${s.label}`}
            title={s.label}
          />
        ))}
      </div>
    </nav>
  );
}
