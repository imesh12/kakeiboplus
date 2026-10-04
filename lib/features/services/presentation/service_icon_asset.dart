/// Approved bundled artwork, keyed only by the persisted service catalog ID.
/// No title matching and no domain/database dependency on asset paths.
String? serviceIconAssetFor(String? serviceIdentityKey) => switch (serviceIdentityKey) {
  'netflix' => 'assets/icons/services/netflix.png',
  'youtube' || 'youtubePremium' => 'assets/icons/services/youtube.png',
  'spotify' => 'assets/icons/services/spotify.png',
  'chatgpt' => 'assets/icons/services/chatgpt.png',
  'gemini' => 'assets/icons/services/gemini.png',
  'steam' => 'assets/icons/services/steam.png',
  'claude' => 'assets/icons/services/claude.png',
  'adobe' => 'assets/icons/services/adobe.png',
  'github' => 'assets/icons/services/github.png',
  'ai' => 'assets/icons/services/ai-generic.png',
  'other' => 'assets/icons/services/other-generic.png',
  'icloud' || 'appleMusic' => 'assets/icons/services/apple-services.png',
  'primeVideo' || 'aws' => 'assets/icons/services/amazon-services.png',
  'googleDrive' || 'googleOne' || 'googleCloud' || 'googleWorkspace' =>
    'assets/icons/services/google-services.png',
  'microsoft365' || 'azure' => 'assets/icons/services/microsoft-services.png',
  _ => null,
};
