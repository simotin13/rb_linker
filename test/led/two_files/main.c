#include "iodefine.h"
#pragma section ResetPRG

void main(void)
{
    volatile int i;
    volatile unsigned char reg; 

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
