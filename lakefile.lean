import Lake
open Lake DSL

package cairn where
  version := v!"0.1.0"
  leanOptions := #[
    ⟨`autoImplicit, false⟩,
    ⟨`relaxedAutoImplicit, false⟩,
    ⟨`weak.linter.dupNamespace, false⟩
  ]

def commonLinkArgs : Array String := #[
  "-framework", "Metal",
  "-framework", "Cocoa",
  "-framework", "QuartzCore",
  "-framework", "Foundation",
  "-lobjc",
  "-L/opt/homebrew/lib",
  "-L/usr/local/lib",
  "-lfreetype",
  "-lassimp",
  "-lc++"
]

require afferent from git "https://github.com/nathanial/afferent" @ "v0.0.2"
require crucible from git "https://github.com/nathanial/crucible" @ "v0.0.7"
require collimator from git "https://github.com/nathanial/collimator" @ "v0.0.4"
require plausible from git "https://github.com/leanprover-community/plausible.git" @ "v4.26.0"

@[default_target]
lean_lib Cairn where
  roots := #[`Cairn]

lean_exe cairn where
  root := `Main
  moreLinkArgs := commonLinkArgs

lean_lib Tests where
  roots := #[`Tests]
  globs := #[.submodules `Tests]

@[test_driver]
lean_exe cairn_tests where
  root := `Tests.Main
  moreLinkArgs := commonLinkArgs
