#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <string.h>
#define LOAD(name, type) type name = (type)dlsym(lib, #name); if (!name) { fprintf(stderr, "Missing %s\n", #name); return 2; }
typedef int (*fn_int_void)(void);
typedef int (*fn_int_u32)(uint32_t);
typedef const char *(*fn_str_void)(void);
typedef const char *(*fn_str_int)(int);
typedef int (*fn_int_int)(int);
typedef void *(*fn_ptr_int)(int);
typedef uint8_t (*fn_button)(void *,int);
typedef int16_t (*fn_axis)(void *,int);
typedef void (*fn_void_void)(void);
typedef void (*fn_void_ptr)(void *);
int main(int argc, char **argv) {
    if (argc < 2) return 2;
    void *lib=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);
    if (!lib) { fprintf(stderr,"%s\n",dlerror()); return 2; }
    LOAD(SDL_Init,fn_int_u32); LOAD(SDL_GetError,fn_str_void);
    LOAD(SDL_NumJoysticks,fn_int_void); LOAD(SDL_JoystickNameForIndex,fn_str_int);
    LOAD(SDL_IsGameController,fn_int_int); LOAD(SDL_GameControllerOpen,fn_ptr_int);
    LOAD(SDL_GameControllerGetButton,fn_button); LOAD(SDL_GameControllerGetAxis,fn_axis);
    LOAD(SDL_GameControllerClose,fn_void_ptr); LOAD(SDL_PumpEvents,fn_void_void); LOAD(SDL_Quit,fn_void_void);
    if (SDL_Init(0x200|0x2000)) { fprintf(stderr,"SDL_Init: %s\n",SDL_GetError()); return 1; }
    SDL_PumpEvents(); int count=SDL_NumJoysticks(); printf("SDL devices: %d\n",count);
    void *pads[16]={0}; uint8_t lastButtons[16][15]; int16_t lastAxes[16][6];
    memset(lastButtons,0xff,sizeof(lastButtons)); memset(lastAxes,0,sizeof(lastAxes));
    for (int i=0;i<count && i<16;i++) {
        printf("%d name=%s mapped=%d\n",i,SDL_JoystickNameForIndex(i),SDL_IsGameController(i));
        if (SDL_IsGameController(i)) pads[i]=SDL_GameControllerOpen(i);
    }
    fflush(stdout);
    int seconds=argc>2?atoi(argv[2]):1; if(seconds>60)seconds=60;
    for(int tick=0;tick<seconds*30;tick++) {
        SDL_PumpEvents();
        for(int i=0;i<count && i<16;i++) if(pads[i]) {
            uint8_t buttons[15]; int16_t axes[6]; int changed=0;
            for(int j=0;j<15;j++) { buttons[j]=SDL_GameControllerGetButton(pads[i],j); if(buttons[j]!=lastButtons[i][j])changed=1; }
            for(int j=0;j<6;j++) { axes[j]=SDL_GameControllerGetAxis(pads[i],j); if(abs((int)axes[j]-lastAxes[i][j])>2000)changed=1; }
            if(changed) {
                printf("t=%.2f device=%d buttons=",tick/30.0,i);
                for(int j=0;j<15;j++)printf("%d",buttons[j]);
                printf(" axes=");for(int j=0;j<6;j++)printf("%d%s",axes[j],j==5?"\n":",");
                memcpy(lastButtons[i],buttons,sizeof(buttons));memcpy(lastAxes[i],axes,sizeof(axes));fflush(stdout);
            }
        }
        usleep(33333);
    }
    for(int i=0;i<16;i++)if(pads[i])SDL_GameControllerClose(pads[i]);
    SDL_Quit(); dlclose(lib); return 0;
}
