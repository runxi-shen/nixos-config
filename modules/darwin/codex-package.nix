# Use OpenAI's complete Mac release so the CLI can keep up with model support
# independently of the system nixpkgs pin. Keep the helpers and resource layout
# together: the CLI resolves them relative to its installed package.
{ lib, stdenvNoCC, fetchurl, installShellFiles }:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codex";
  version = "0.165.0";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-package-aarch64-apple-darwin.tar.gz";
    hash = "sha256-NNEjhNkPjgmwuauqvyoKwCpSCTsTFQSuryghB/VKRLI=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ installShellFiles ];
  dontBuild = true;
  # Preserve the upstream binaries and their signatures.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R bin codex-package.json codex-path codex-resources "$out/"
    installShellCompletion --cmd codex \
      --bash <("$out/bin/codex" completion bash) \
      --fish <("$out/bin/codex" completion fish) \
      --zsh <("$out/bin/codex" completion zsh)
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$("$out/bin/codex" --version)" = "codex-cli ${finalAttrs.version}"
    "$out/bin/codex-code-mode-host" --help > /dev/null
    "$out/codex-path/rg" --version > /dev/null
    # 0.165.0 dropped the bundled zsh and ships a voice host instead. It is
    # an audio daemon with no --help/--version, so just verify it is present
    # and executable.
    test -x "$out/codex-resources/voice/bin/codex-voice-host"
    runHook postInstallCheck
  '';

  meta = {
    description = "OpenAI Codex CLI with its bundled runtime helpers";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
