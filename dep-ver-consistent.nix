# dep-ver-consistent.nix – check whether there are inconsistent versions of a
#                          certain dependency in the closure of a package
# 
# - does not take into account the BuildBuild and target dependencies (see
#   function deps)
# - compares only package version attributes
# - main function is after first let ... in

# lib is the attr from nixpkgs
lib:

with builtins;
with lib;

# helper functions outside the main closure
let
  deps = pkg: if !isAttrs pkg then [] else concatLists (attrValues {
    inherit (pkg)
    #depsBuildBuild
    nativeBuildInputs
    #depsBuildTarget
    depsHostHost
    buildInputs
    #depsTargetTarget

    #depsBuildBuildPropagated
    propagatedNativeBuildInputs
    #depsBuildTargetPropagated
    depsHostHostPropagated
    propagatedBuildInputs
    #depsTargetTargetPropagated
    ;
  });

  transDepInstances = depth: depPname: pkg:
    let
      predPname = x: isAttrs x && getName x.name == depPname;
      go = depth: pkg:
        let deps' = deps pkg;
        in map (x: { parent = pkg; pkg = x; }) (filter predPname deps')
        ++ optionals (depth > 0) (map (x: go (depth - 1) x) deps');
    in flatten (go depth pkg);
in

# the main function :: Bool -> Int -> String -> Derivation -> Bool
# example: import dep-ver-consistent.nix lib false 4 "qtbase" carla
verbose: depth: depPname: pkg:
let
  transDepInstances' = transDepInstances depth depPname (builtins.trace "pkg is ${pkg.name}" pkg);
  dep0 = head transDepInstances';
  v0 = (builtins.trace "dep0 is ${dep0.pkg.outPath}" dep0).pkg.version;
  traceV = x: if verbose then trace x else id;
in flip all transDepInstances' (x:
  traceV ((builtins.trace "x is ${x.pkg.outPath}" x).pkg.outPath) (x.pkg.version == v0)
  || flip trace false ''
    x.pkg.version == ${x.pkg.version} != ${v0} == dep0.pkg.version
      where
        dep0.parent.outPath == ${dep0.parent.outPath}
        dep0.pkg.outPath == ${dep0.pkg.outPath}
        x.parent.outPath == ${x.parent.outPath}
        x.pkg.outPath == ${x.pkg.outPath}
  '')
