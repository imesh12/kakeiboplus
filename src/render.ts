import * as sections from "./sections";
import { ProblemSection, TrustSection } from "./stories";

/** Shared by the build-time static renderer and the development entry point. */
export function renderLanding(): string {
  return `${sections.LandingHeader()}<main id="main">${sections.HeroSection()}${ProblemSection()}${sections.LanguageShowcase()}${sections.CurrencyShowcase()}${sections.FxShowcase()}${sections.FeatureShowcase()}${sections.GrowthSection()}${sections.CompanionShowcase()}${TrustSection()}${sections.PricingSection()}${sections.FinalCTA()}</main>${sections.LandingFooter()}${sections.Dialogs()}`;
}
