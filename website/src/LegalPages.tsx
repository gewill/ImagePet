import React from "react";
import { SiteHeader } from "./SiteHeader";

interface LegalPageProps {
  onBack: (path: string) => void;
  activePetIndex: number;
  setActivePetIndex: React.Dispatch<React.SetStateAction<number>>;
  petThemes: Array<{ name: string; description: string; image: string }>;
  navItems: Array<{ label: string; href: string }>;
  appStoreHref: string;
  hasMacAppStore: boolean;
  appName: string;
}

function FloatingPet({
  activePetIndex,
  setActivePetIndex,
  petThemes
}: {
  activePetIndex: number;
  setActivePetIndex: React.Dispatch<React.SetStateAction<number>>;
  petThemes: Array<{ name: string; description: string; image: string }>;
}) {
  return (
    <div
      className="floating-desktop-pet"
      onClick={() => setActivePetIndex((prev) => (prev + 1) % petThemes.length)}
      title="Click to switch theme"
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
  );
}

export function TermsPage({
  onBack,
  activePetIndex,
  setActivePetIndex,
  petThemes,
  navItems,
  appStoreHref,
  hasMacAppStore,
  appName
}: LegalPageProps) {
  return (
    <main className="site-shell">
      <SiteHeader
        currentPath="/en/terms"
        navigateTo={onBack}
        navItems={navItems}
        appStoreHref={appStoreHref}
        hasMacAppStore={hasMacAppStore}
        appName={appName}
      />
      <div className="legal-page-container">
        <div className="legal-page-card">
          <div className="legal-page-header">
            <h1>Terms of Use</h1>
            <p className="legal-last-updated">Last updated: June 2026</p>
          </div>

          <div className="legal-page-section">
            <h2>Apple Media Services</h2>
            <p>
              ImagePet is distributed through the Apple App Store and is subject to the{" "}
              <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/" target="_blank" rel="noopener noreferrer">
                Apple Media Services Terms and Conditions
              </a>
              .
            </p>
          </div>

          <div className="legal-page-section">
            <h2>Acceptable Use</h2>
            <p>You may use ImagePet for image compression and optimization. You agree not to use the app for any unlawful purposes or in any way that could damage, disable, or impair the app or interfere with any other party's use of the app.</p>
          </div>

          <div className="legal-page-section">
            <h2>Disclaimer of Warranties</h2>
            <p>ImagePet is provided as is without any warranties, express or implied. We do not warrant that the app will be uninterrupted, error-free, or secure.</p>
          </div>

          <div className="legal-page-section">
            <h2>Limitation of Liability</h2>
            <p>In no event shall the developers of ImagePet be liable for any indirect, incidental, special, consequential, or punitive damages arising out of or in connection with your use of the app.</p>
          </div>

          <div className="legal-page-section">
            <h2>Changes to Terms</h2>
            <p>We reserve the right to modify these terms at any time. Continued use of the app after changes constitutes acceptance of the new terms.</p>
          </div>

          <div className="legal-page-section">
            <h2>Contact</h2>
            <p>
              If you have any questions about these Terms of Use, please contact us at{" "}
              <a href="mailto:531sunlight@gmail.com">531sunlight@gmail.com</a>.
            </p>
          </div>

          <div className="legal-page-footer">
            <p>&copy; 2026 ImagePet. All rights reserved.</p>
          </div>
        </div>
      </div>

      <FloatingPet
        activePetIndex={activePetIndex}
        setActivePetIndex={setActivePetIndex}
        petThemes={petThemes}
      />
    </main>
  );
}

export function PrivacyPage({
  onBack,
  activePetIndex,
  setActivePetIndex,
  petThemes,
  navItems,
  appStoreHref,
  hasMacAppStore,
  appName
}: LegalPageProps) {
  return (
    <main className="site-shell">
      <SiteHeader
        currentPath="/en/privacy"
        navigateTo={onBack}
        navItems={navItems}
        appStoreHref={appStoreHref}
        hasMacAppStore={hasMacAppStore}
        appName={appName}
      />
      <div className="legal-page-container">
        <div className="legal-page-card">
          <div className="legal-page-header">
            <h1>Privacy Policy</h1>
            <p className="legal-last-updated">Last updated: June 2026</p>
          </div>

          <div className="legal-page-section">
            <h2>Introduction</h2>
            <p>This Privacy Policy explains how ImagePet collects, uses, and protects your personal information. We are committed to ensuring that your privacy is protected.</p>
          </div>

          <div className="legal-page-section">
            <h2>Information Collection</h2>
            <p><strong>ImagePet does not collect, store, or upload any private information.</strong> The app performs image compression locally on your device. All files and settings are processed exclusively on your device and are never transmitted to any external servers.</p>
          </div>

          <div className="legal-page-section">
            <h2>Data Storage</h2>
            <p>All data generated by the app (including images and settings) is stored locally on your device.</p>
          </div>

          <div className="legal-page-section">
            <h2>Third-Party Services</h2>
            <p>ImagePet does not integrate with any third-party analytics, advertising, or data collection services.</p>
          </div>

          <div className="legal-page-section">
            <h2>Children's Privacy</h2>
            <p>Our app does not address anyone under the age of 4. We do not knowingly collect personal information from children.</p>
          </div>

          <div className="legal-page-section">
            <h2>Changes to This Policy</h2>
            <p>We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the Last updated date.</p>
          </div>

          <div className="legal-page-section">
            <h2>Contact Us</h2>
            <p>
              If you have any questions about this Privacy Policy, please contact us at{" "}
              <a href="mailto:531sunlight@gmail.com">531sunlight@gmail.com</a>.
            </p>
          </div>

          <div className="legal-page-footer">
            <p>&copy; 2026 ImagePet. All rights reserved.</p>
          </div>
        </div>
      </div>

      <FloatingPet
        activePetIndex={activePetIndex}
        setActivePetIndex={setActivePetIndex}
        petThemes={petThemes}
      />
    </main>
  );
}
