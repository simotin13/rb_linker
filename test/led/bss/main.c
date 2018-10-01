#include "iodefine.h"
#pragma section ResetPRG

static int count;
void main(void)
{
    volatile int i;
    volatile unsigned char reg; 
    
    count = 1000;

    PORTA.PDR.BIT.B0 = 1;
    while(1){
        if (i % count == 0) {
            reg  = PORTA.PODR.BIT.B0;
            PORTA.PODR.BIT.B0 = ~reg;
            i = 0;
        }
        i++;
    }
}
