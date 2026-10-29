name = "marianoguerra/wisp"

version = "0.0.0"

import {
  "marianoguerra/wap@0.4.2",
  "marianoguerra/wax@0.4.2",
  "marianoguerra/shrubbery@0.1.2",
  "marianoguerra/error-report@0.1.1",
}

license = "Apache-2.0"

description = "Lexically scoped immutable scripting through wap"

// See lib/moon.mod for why warning 79 is off.

warnings = "-implicit_impl_as_method"
