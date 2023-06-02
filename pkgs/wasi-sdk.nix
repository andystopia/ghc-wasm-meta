{ hostPlatform, runtimeShellPackage, stdenv, stdenvNoCC, }:
let
  common-src = builtins.fromJSON (builtins.readFile ../autogen.json);
  wasi-sdk-key =
    if hostPlatform.isDarwin then
      "wasi-sdk_darwin"
    else if hostPlatform.isAarch64 then
      "wasi-sdk_aarch64_linux"
    else
      "wasi-sdk";
  wasi-sdk-src = builtins.fetchTarball common-src."${wasi-sdk-key}";
  libffi-wasm-src = builtins.fetchTarball common-src.libffi-wasm;
in
stdenvNoCC.mkDerivation {
  name = "wasi-sdk";

  dontUnpack = true;

  buildInputs = [ runtimeShellPackage ];

  cc_for_build = "${stdenv.cc}/bin/cc";

  installPhase = ''
    runHook preInstall

    cp -a ${wasi-sdk-src} $out
    chmod -R u+w $out

    mkdir $out/nix-support
    substituteAll ${./wasi-sdk-setup-hook.sh} $out/nix-support/setup-hook

    patchShebangs $out

    cp -a ${libffi-wasm-src}/libffi-wasm/include/. $out/share/wasi-sysroot/include
    cp -a ${libffi-wasm-src}/libffi-wasm/lib/. $out/share/wasi-sysroot/lib/wasm32-wasi

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    pushd "$(mktemp -d)"
    echo '#include <iostream>' >> test.cpp
    echo 'void ffi_alloc_prep_closure(void);' >> test.cpp
    echo 'int main(void) { std::cout << &ffi_alloc_prep_closure << std::endl; }' >> test.cpp
    $out/bin/clang++ test.cpp -lffi -o test.wasm
    popd

    runHook postInstallCheck
  '';

  dontFixup = true;

  allowedReferences = [ "out" runtimeShellPackage stdenv.cc ];
}
