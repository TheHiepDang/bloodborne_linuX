{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  inputsFrom = [ (import ../shell.nix { inherit pkgs; }) ];
  packages = [ pkgs.vulkan-validation-layers pkgs.mesa.drivers pkgs.jq
               pkgs.libjack2 pkgs.libxdmcp pkgs.ccache ];
  CMAKE_CXX_COMPILER_LAUNCHER = "ccache";
  CMAKE_C_COMPILER_LAUNCHER = "ccache";
  VK_DRIVER_FILES = "${pkgs.mesa.drivers}/share/vulkan/icd.d/lvp_icd.x86_64.json";
  VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";
}
