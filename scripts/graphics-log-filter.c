#include <stdio.h>
#include <string.h>
#include <strings.h>
/* Keep only graphics subsystem lines; raw Steam output never reaches disk. */
static int accepted(const char *s) {
    const char *private_words[] = {"password", "token", "authorization", "https://", "http://", "steamapi", "login", NULL};
    for (int i = 0; private_words[i]; ++i) if (strcasestr(s, private_words[i])) return 0;
    /* Exception dispatch metadata only, never arbitrary SEH payload/string dumps. */
    if (strstr(s, ":trace:seh:dispatch_exception code=")) return 1;
    if (strstr(s, ":trace:mfreadwrite:MFCreateSourceReader")) return 1;
    const char *media_tags[] = {":warn:mfplat:", ":err:mfplat:", ":warn:mfreadwrite:", ":err:mfreadwrite:", ":warn:mf:", ":err:mf:", ":warn:winegstreamer:", ":err:winegstreamer:", NULL};
    for (int i = 0; media_tags[i]; ++i) if (strstr(s, media_tags[i])) return 1;
    const char *tags[] = {"[mvk-error]", "[mvk-warn]", ":err:vkd3d", ":warn:vkd3d", ":err:vulkan", ":warn:vulkan", "err:   D3D", "err:   DXGI", NULL};
    for (int i = 0; tags[i]; ++i) if (strstr(s, tags[i])) return 1;
    return 0;
}
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    FILE *out = fopen(argv[1], "a"); if (!out) return 1;
    char line[8192];
    while (fgets(line, sizeof(line), stdin)) {
        int complete = strchr(line, '\n') != NULL;
        if (accepted(line)) { fputs(line, out); if (!complete) fputc('\n', out); fflush(out); }
        if (!complete) { int c; while ((c = getchar()) != '\n' && c != EOF) {} }
    }
    fclose(out); return ferror(stdin) ? 1 : 0;
}
