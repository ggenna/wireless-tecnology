// $Id: RadioCountToLedsAppC.nc,v 1.4 2006/12/12 18:22:48 vlahan Exp $

/*									tab:4
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */
 
#include "Beacon.h"
#include "printf.h"

/**
 * Configuration for the RadioCountToLeds application. RadioCountToLeds 
 * maintains a 4Hz counter, broadcasting its value in an AM packet 
 * every time it gets updated. A RadioCountToLeds node that hears a counter 
 * displays the bottom three bits on its LEDs. This application is a useful 
 * test to show that basic AM communication and timers work.
 *
 * @author Philip Levis
 * @date   June 6 2005
 */

configuration BeaconAppC {}
implementation {
  components MainC, BeaconC as App, LedsC;
  components new AMSenderC(AM_BEACONMSG);
  components new AMReceiverC(AM_BEACONMSG);
  components new TimerMilliC() as Timer0;
  components ActiveMessageC;
  //added as a part of 1.1
  components HplMsp430GeneralIOC;
  components HplMsp430InterruptC;
  //over
  //added as a part of 1.2
  
  
  
 /*
  components new SensirionSht11C() as Temp;  
  components new SensirionSht11C() as Humid;
  components new HamamatsuS1087ParC() as PAR;
  components new HamamatsuS10871TsrC() as TSR;
  */
   components UserButtonC;
  
  //end



  App.Boot -> MainC.Boot;
  App.Receive -> AMReceiverC;
  App.Radio -> ActiveMessageC;
  App.Leds -> LedsC;
  App.Timer0 -> Timer0;
  App.Packet -> AMSenderC;
  App.AMSend -> AMSenderC;
  

  //added as a part of 1.1

  App.MSP430Interrupt -> HplMsp430InterruptC.Port27;
  App.MSP430GeneralIO -> HplMsp430GeneralIOC.Port27;
  
  //added as a part of 1.2
  /*
  App.Temperature -> Temp.Temperature; 
  App.Humidity -> Humid.Humidity; 
  App.PAR -> PAR;
  App.TSR -> TSR;
  */
    
  components new MTS_EM1000C() as EM1000;
  App.AccX  	 -> EM1000.ADXL321_ACC_Axis_X;   // Accelerometer X axis
  App.AccY  	 -> EM1000.ADXL321_ACC_Axis_Y;   // Accelerometer Y axis
  App.Temperature -> EM1000.Sensirion_Temperature;      // Temperature
  App.Humidity 	 -> EM1000.Sensirion_Humidity;      // Humidity
    App.PAR      -> EM1000.S1087_PAR_VL_Calibration_on; // PAR calibrato  
    App.TSR       -> EM1000.S1087_01_TSR_IR; // TSR



 // App.Get -> UserButtonC;
  App.Notify -> UserButtonC;

}




