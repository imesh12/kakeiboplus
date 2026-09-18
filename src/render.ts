import * as sections from './sections';

/** Shared by the build-time static renderer and the development entry point. */
export function renderLanding(): string {
  return `${sections.LandingHeader()}<main id="main">${sections.HeroSection()}${sections.LanguageShowcase()}${sections.CurrencyShowcase()}${sections.FxShowcase()}${sections.CompanionShowcase()}${sections.FeatureShowcase()}${sections.GrowthSection()}${sections.PricingSection()}${sections.FinalCTA()}</main>${sections.LandingFooter()}${sections.Dialogs()}`;
}
