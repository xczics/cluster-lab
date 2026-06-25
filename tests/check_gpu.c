/**
 * check_gpu.c — Verify GRES GPU allocation
 * 
 * Compile: gcc -o check_gpu check_gpu.c -lm
 * Run:     srun --gres=gpu:1 ./check_gpu
 *
 * This program checks which fake GPU devices were allocated
 * by Slurm GRES by reading /dev/fake_gpu*.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <glob.h>

int main(int argc, char *argv[]) {
    char hostname[256];
    char **env_var;
    int gpu_count = 0;

    gethostname(hostname, sizeof(hostname));
    printf("GPU Check on %s\n", hostname);
    printf("==================\n");

    // Check SLURM environment variables
    printf("\nSlurm GRES environment:\n");
    const char *gres_list = getenv("SLURM_JOB_GRES");
    if (gres_list) {
        printf("  SLURM_JOB_GRES = %s\n", gres_list);
    } else {
        printf("  SLURM_JOB_GRES = (not set — no GPU allocated)\n");
    }

    // Scan for fake GPU devices
    glob_t globbuf;
    int ret = glob("/dev/fake_gpu*", GLOB_NOSORT, NULL, &globbuf);

    printf("\nFake GPU devices found:\n");
    switch (ret) {
        case 0:
            for (size_t i = 0; i < globbuf.gl_pathc; i++) {
                printf("  [%zu] %s\n", i, globbuf.gl_pathv[i]);
                gpu_count++;
            }
            break;
        case GLOB_NOMATCH:
            printf("  (none — fake GPU devices not present)\n");
            break;
        default:
            printf("  (glob error)\n");
            break;
    }
    globfree(&globbuf);

    printf("\nSummary: %s — %d GPU(s) reported\n", hostname, gpu_count);

    if (gres_list && gpu_count > 0) {
        printf("✅ GPU allocation successful!\n");
        return 0;
    } else {
        printf("ℹ️  GPU simulation: Slurm GRES allocated but\n");
        printf("   device files may need manual creation.\n");
        return 1;
    }
}
