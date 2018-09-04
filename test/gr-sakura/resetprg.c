#include "iodefine.h"

#pragma section ResetPRG
#pragma entry PowerON_Reset_PC

// use stack
#pragma stacksize su=0x100
#pragma stacksize si=0x300

void main(void);

void PowerON_Reset_PC(void) {
    #if 0
    while(1){
        if (i % 1000 == 0) {
            reg  = PORTA.PODR.BIT.B0;
            PORTA.PODR.BIT.B0 = ~reg;
            i = 0;
        }
        i++;
    }
    #endif
    main();
}

#pragma section C FIXEDVECT
const void (*const func)(void)= PowerON_Reset_PC;
