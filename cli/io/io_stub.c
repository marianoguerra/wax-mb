/* Byte-exact writes to stdout and stderr, which MoonBit's core has no binding
 * for -- `println` appends a newline and offers no stderr counterpart.
 *
 * Both streams are needed, and kept apart: the differential harness reads
 * formatted output from stdout while reading diagnostics from stderr, so
 * mixing them would make every comparison meaningless. */
#include <stdio.h>
#ifdef _WIN32
#include <io.h>
#define wax_isatty _isatty
#define wax_fileno _fileno
#else
#include <unistd.h>
#define wax_isatty isatty
#define wax_fileno fileno
#endif
#include "moonbit.h"

/* Whether a stream is a terminal: 1 for stdout, 2 for stderr. This is the
 * `auto` in --color=auto, and it is asked of the DESTINATION, so a redirect to
 * a file never receives escape codes. */
MOONBIT_FFI_EXPORT int32_t wax_isatty_fd(int32_t which) {
    FILE *f = (which == 2) ? stderr : stdout;
    return wax_isatty(wax_fileno(f)) ? 1 : 0;
}

MOONBIT_FFI_EXPORT void wax_write_stdout(moonbit_bytes_t s, int32_t len) {
    fwrite((const char *)s, 1, (size_t)len, stdout);
}

MOONBIT_FFI_EXPORT void wax_write_stderr(moonbit_bytes_t s, int32_t len) {
    fwrite((const char *)s, 1, (size_t)len, stderr);
    /* Flush per write, so stdout/stderr interleaving stays deterministic when
     * a parent process or a cram test captures both. */
    fflush(stderr);
}
