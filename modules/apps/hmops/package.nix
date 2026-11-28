{ rustPlatform, lib, makeWrapper, controller ? null }:
rustPlatform.buildRustPackage {
  pname = "hmops";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./Cargo.toml ./Cargo.lock ./src ];
  };
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = lib.optional (controller != null) makeWrapper;
  postFixup = lib.optionalString (controller != null) ''
    wrapProgram "$out/bin/hmops" --prefix PATH : ${lib.makeBinPath [ controller ]}
  '';
  meta.mainProgram = "hmops";
}
