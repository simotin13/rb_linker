#include "iodefine.h"

#pragma section ResetPRG
#pragma entry PowerON_Reset_PC

void PowerON_Reset_PC(void) {
    int i;
    unsigned char reg; 
    PORTA.PDR.BIT.B0 = 1;
    while(1){
        if (i % 1000 == 0) {
            reg  = PORTA.PODR.BIT.B0;
            PORTA.PODR.BIT.B0 = ~reg;
            i = 0;
        }
        i++;
    }
}

#pragma section C FIXEDVECT
const void (*const func)(void)= PowerON_Reset_PC;
