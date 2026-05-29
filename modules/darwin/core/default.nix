{ myLib, ... }:

{
  imports = myLib.mkAutoImports { dir = ./.; };
}
