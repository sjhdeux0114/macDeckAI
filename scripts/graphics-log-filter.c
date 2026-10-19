#include <stdio.h>
#include <string.h>
#include <strings.h>
/* Keep only graphics subsystem lines; raw Steam output never reaches disk. */
static int accepted(const char *s) {
    const char *private_words[] = {"password", "token", "authorization", "https://", "http://", "steamapi", "login", NULL};
    for (int i = 0; private_words[i]; ++i) if (strcasestr(s, private_words[i])) return 0;
    if (!strncmp(s, "err:   DXSO ", sizeof("err:   DXSO ") - 1) ||
        !strncmp(s, "err:   FFP ", sizeof("err:   FFP ") - 1)) return 1;
    if (!strncmp(s, "MacDeck renderer router: module=macdeck_", sizeof("MacDeck renderer router: module=macdeck_") - 1)) return 1;
    if (!strncmp(s, "wine: Unhandled page fault", sizeof("wine: Unhandled page fault") - 1) ||
        !strncmp(s, "wine: Unhandled exception", sizeof("wine: Unhandled exception") - 1) ||
        strstr(s, ":err:seh:start_debugger")) return 1;
    if (strstr(s, "Using GDI for swapchain presentation.")) return 1;
    /* Native Metal validation assertions precede Wine's SIGABRT dispatch. */
    if (strcasestr(s, "failed assertion") || strstr(s, "Assertion failed:")) return 1;
    if ((strstr(s, "err: ") || strstr(s, "warn: ")) &&
        (strstr(s, "d3d9:") || strstr(s, "d9 layer extent:") || strstr(s, "d9 swap params"))) return 1;
    /* Exception dispatch metadata only, never arbitrary SEH payload/string dumps. */
    if (strstr(s, ":trace:seh:dispatch_exception code=")) return 1;
    if (strstr(s, ":trace:mfreadwrite:MFCreateSourceReader")) return 1;
    const char *media_tags[] = {":warn:mfplat:", ":err:mfplat:", ":warn:mfreadwrite:", ":err:mfreadwrite:", ":warn:mf:", ":err:mf:", ":warn:winegstreamer:", ":err:winegstreamer:", NULL};
    for (int i = 0; media_tags[i]; ++i) if (strstr(s, media_tags[i])) return 1;
    const char *tags[] = {":err:d3d:", ":warn:d3d:", ":err:d3d9:", ":warn:d3d9:", "[mvk-error]", "[mvk-warn]", ":err:vkd3d", ":warn:vkd3d", ":err:vulkan", ":warn:vulkan", "err:   D3D", "err:   DXGI", NULL};
    for (int i = 0; tags[i]; ++i) if (strstr(s, tags[i])) return 1;
    return 0;
}
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    FILE *out = fopen(argv[1], "a"); if (!out) return 1;
    char line[8192], previous[8192] = "";
    unsigned long long repeated = 0;
    while (fgets(line, sizeof(line), stdin)) {
        int complete = strchr(line, '\n') != NULL;
        if (accepted(line)) {
            if (!strcmp(line, previous)) { ++repeated; }
            else {
                if (repeated) fprintf(out, "MacDeck: suppressed %llu repeated graphics messages\n", repeated);
                repeated = 0;
                snprintf(previous, sizeof(previous), "%s", line);
                fputs(line, out); if (!complete) fputc('\n', out); fflush(out);
            }
        }
        if (!complete) { int c; while ((c = getchar()) != '\n' && c != EOF) {} }
    }
    if (repeated) fprintf(out, "MacDeck: suppressed %llu repeated graphics messages\n", repeated);
    int failed = ferror(stdin) || ferror(out);
    if (fclose(out)) failed = 1;
    return failed ? 1 : 0;
}
