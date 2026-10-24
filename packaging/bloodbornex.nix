# FSR 3 preview: cached GTK/Mesa packages, own identity and user profile. No proprietary models.
{ pkgs ? import <nixpkgs> {}
, runtimePaths ? import ./runtime-paths.nix
}:
let
  lib = pkgs.lib;
  root = ./..;
  assets = [ "launcher" "scripts" "patches" "tools/fsr4cap" ];
  wanted = [ "run.sh" "LICENSE" "out" "out/bb-probe" "out/bb-gpu-capabilities"
             "out/gpu" "out/gpu/libbbgpu.so" "tools" ] ++ assets;
  src = builtins.path {
    name = "bloodbornex-src";
    path = root;
    filter = path: type:
      let rel = lib.removePrefix (toString root + "/") (toString path);
      in builtins.elem rel wanted || lib.any (dir: lib.hasPrefix (dir + "/") rel) assets;
  };
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  fontsConf = pkgs.writeText "bloodbornex-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <dir>${pkgs.dejavu_fonts}/share/fonts</dir>
      <dir>${pkgs.adwaita-fonts}/share/fonts</dir>
      <dir>/usr/share/fonts</dir>
      <dir prefix="xdg">fonts</dir>
      <cachedir prefix="xdg">bloodbornex/fontconfig</cachedir>
      <include ignore_missing="yes">${pkgs.fontconfig.out}/etc/fonts/conf.d</include>
    </fontconfig>
  '';
  icds = lib.concatMapStringsSep ":"
    (name: "${pkgs.mesa.drivers}/share/vulkan/icd.d/${name}_icd.x86_64.json")
    [ "radeon" "intel" "lvp" ];
in pkgs.stdenv.mkDerivation {
  pname = "bloodbornex";
  version = "fg-preview.1";
  inherit src;
  nativeBuildInputs = [ pkgs.makeShellWrapper pkgs.wrapGAppsHook4 pkgs.gobject-introspection ];
  buildInputs = [ pkgs.gtk4 pkgs.libadwaita pkgs.adwaita-icon-theme pkgs.librsvg ]
    ++ map builtins.storePath runtimePaths;
  dontBuild = true;
  dontConfigure = true;
  dontPatchELF = true;
  dontWrapGApps = true;
  stripDebugList = [ "share/bloodbornex/bin/gpu" ];
  installPhase = ''
    runHook preInstall
    d=$out/share/bloodbornex
    mkdir -p $d/bin/gpu $d/tools $out/bin $out/libexec
    cp run.sh LICENSE $d/
    cp -r launcher scripts patches $d/
    cp -r tools/fsr4cap $d/tools/
    install -m755 out/bb-probe out/bb-gpu-capabilities $d/bin/
    install -m755 out/gpu/libbbgpu.so $d/bin/gpu/
    strip --strip-debug $d/bin/bb-probe $d/bin/bb-gpu-capabilities
    runHook postInstall
  '';
  postFixup = ''
    gcc -O2 -Wall -Werror -static -L${pkgs.glibc.static}/lib \
      -DTARGET="\"$out/libexec/BloodborneX\"" ${./bbport-entry.c} -o $out/bin/BloodborneX
    makeShellWrapper ${python}/bin/python3 $out/libexec/BloodborneX \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "$out/share/bloodbornex/launcher/bloodbornex_entry.py ${python}/bin/python3 $out/share/bloodbornex/launcher/bbport_launcher.py" \
      --set BB_PREBUILT 1 --set PYTHON ${python}/bin/python3 \
      --set BB_BUNDLED_VK_DRIVER_FILES ${icds} \
      --set BB_VULKANINFO ${pkgs.vulkan-tools}/bin/vulkaninfo \
      --set-default LC_ALL C.UTF-8 \
      --set FONTCONFIG_FILE ${fontsConf} \
      --prefix XDG_DATA_DIRS : ${pkgs.adwaita-icon-theme}/share:${pkgs.hicolor-icon-theme}/share \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.libglvnd pkgs.libx11 pkgs.libxext ]} \
      --prefix PATH : ${lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.util-linux pkgs.procps
                                        pkgs.gawk pkgs.gnused pkgs.gnugrep ]}
  '';
  meta.mainProgram = "BloodborneX";
}
