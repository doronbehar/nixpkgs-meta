#!/usr/bin/env bash

# Example usage:
# ./get-maintainers.sh package1 package2 package3
# or from stdin:
# cat packages.txt | ./get-maintainers.sh
# echo -e "hello\ngit\nvim" | ./get-maintainers.sh

# Read packages from arguments or stdin
if [ $# -gt 0 ]; then
  # Packages provided as arguments
  packages=("$@")
else
  # Read packages from stdin
  mapfile -t packages
fi

# Build Nix array string
nix_array=""
for pkg in "${packages[@]}"; do
  # Skip empty lines
  [[ -z "$pkg" ]] && continue
  nix_array+="\"$pkg\" "
done

nix eval --impure --expr '
let
  pkgs = import <nixpkgs> {};

  getGithubHandle = maintainer:
    if maintainer ? github then
      "@${maintainer.github}"
    else
      maintainer.name or "unknown";

  # Helper to get nested attributes like "python3Packages.numpy"
  # Returns { found = true/false; threw = true/false; value = pkg or null }
  getNestedAttr = attrPath:
    let
      parts = builtins.filter builtins.isString (builtins.split "\\." attrPath);
      helper = attrs: path:
        if path == [] then { found = true; threw = false; value = attrs; }
        else if !builtins.isAttrs attrs then { found = false; threw = false; value = null; }
        else
          let
            attrName = builtins.head path;
            # Check if attribute exists first
            hasAttr = builtins.tryEval (attrs ? ${attrName});
          in
            if !hasAttr.success then
              { found = false; threw = true; value = null; }
            else if !hasAttr.value then
              { found = false; threw = false; value = null; }
            else
              let
                attrResult = builtins.tryEval (builtins.getAttr attrName attrs);
              in
                if !attrResult.success then
                  { found = false; threw = true; value = null; }
                else
                  helper attrResult.value (builtins.tail path);
    in
      helper pkgs parts;

  getMaintainers = attr:
    let
      pkgResult = getNestedAttr attr;
      pkg = pkgResult.value;
      # Try to access meta and maintainers
      metaResult = builtins.tryEval (
        if pkg != null && pkg ? meta && pkg.meta ? maintainers
        then pkg.meta.maintainers
        else []
      );
    in
      if pkgResult.threw || !metaResult.success then
        builtins.trace "WARNING: Package attribute \"${attr}\" throws an error (likely an alias or removed package)" null
      else if !pkgResult.found then
        builtins.trace "WARNING: Package attribute \"${attr}\" does not exist in nixpkgs" null
      else
        let
          maintainers = metaResult.value;
          handles = map getGithubHandle maintainers;
        in
          "- `${attr}` maintainers: [ ${builtins.concatStringsSep " " handles} ]";

  attrs = [ '"$nix_array"' ];
  results = map getMaintainers attrs;
  validResults = builtins.filter (x: x != null) results;
in
  builtins.concatStringsSep "\n" validResults
' --raw
