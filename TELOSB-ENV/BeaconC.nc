/**************************************************************************
*  File name 		: BeaconC.nc
*  AppC file name 	: BeaconAppC.nc
*  Header file name 	: Beacon.h
*  Author 		: Dhruv Vyas 
*  Version		: 1.5
*  
*  Date created on	: 
*  Description 		: 0.1 		: Started off with basic template with successfull migration of header file
*			: 0.2		: Migrating boot.booted() (originally stdcontrol)
*			: 0.3		: Migration complete : compile success
*			: 0.4		: Migrating task sendData()
*			: 0.5		: Migration done
*			: 0.6		: Migrating tast masterTask()
*			: 0.7		: Migration done
*			: 0.8 		: Migration done upto Receive msg code from BeaconM 
*			: 0.9		: Receive msg done
*			: 1.0		: Migrating remaining tasks
*			: 1.1 		: Unlocking MSP interrupts
*			: 1.2 		: Migrating TSR, Temp and humidity functions
*			: 1.3 		: Migrating Rivelatore function
* 			: 1.4		: Added printf intead of using AMsend to UART
* 			: 1.5		: added printf @ send / receive point
************************************************************************************/



#include "Timer.h"
#include "Beacon.h"
#include <UserButton.h>
//#include "printf.h"					//added to monitor results on UART
 

module BeaconC @safe() 
{
	uses 
	{
		interface Leds;
		interface Boot;
		interface Receive;
		interface AMSend;
		interface Timer<TMilli> as Timer0;
		interface SplitControl as Radio;
		interface Packet;

		//added as a part of 1.1
		interface HplMsp430Interrupt as MSP430Interrupt;
    		interface HplMsp430GeneralIO as MSP430GeneralIO;
		//end	
	
		//added as a part of 1.2
		interface Read<uint16_t> as Temperature;
		interface Read<uint16_t> as Humidity;
		interface Read<uint16_t> as PAR;
		interface Read<uint16_t> as TSR;
		interface Read<uint16_t> as AccX;
   		 interface Read<uint16_t> as AccY;
		//end

                // interface Get<button_state_t>;
                 interface Notify<button_state_t>;
	}
}

implementation 
{
	//variables
	
	message_t msg;//buffer used to send message
	message_t buf;//buffer used to receive message
	uint8_t myID; //index in network
	uint8_t i; // index used in cycle for 
	uint16_t nextBeacon = TIME_BEACON; //next time when the trasmission will start
	uint8_t chooseFather; //variable used to choose the father.
	uint8_t positionFather; //value of position father in beacon vector
	uint8_t myIndex; //index in beacon vector
	uint8_t nServedSlave; //number of served slaves
	uint8_t nRegisteredSlave;//number of registered slaves
	uint8_t idToControl; //ID to control if it is inserted in beacon vector
	uint8_t j;		//temp variable
	uint8_t beaconVector[MAX_SLAVE]; //beacon vector
	data_t slaveVector[MAX_SLAVE]; //structure where the mote saves information of its childs
	uint8_t vectorLQI[MAX_SLAVE]; //structure used to save information of lqi value misured in scanning phase
	
	uint8_t user_leds;
	
	
	bool master = FALSE; //set when is master
	bool slave = FALSE; //set when is slave
	bool canSend=FALSE; //set when can send data packet
	bool fila1= FALSE; // set if mote is attach to base station
	bool fila2 = FALSE; // set if the mote is attach to another mote for send packet to base station
	bool servicesSlave=FALSE; //set when the mote must service the child
	bool fatherFind =FALSE; //set when the mote found a father
	bool waiting=FALSE; //set when mote waiting for other slaves
	bool synchronized=FALSE; //set when mote is synchronized with father mote
	bool waitingSon=FALSE; // set when waiting for a child
	bool waitingFather=FALSE; // set when waiting for father
	bool waitingAnotherChild=FALSE; //set when have to serve a child that is the next that i serve now....
	bool forward=FALSE;// set when the mote have to forward the message to child	
	bool present=FALSE; //set when the mote is present in beaconvector and it is attacched to another mote
	bool justRegistered=FALSE; //set when mote is just inserted in network
	bool toControl=FALSE; //set when mote have to be control if his child is inserted in beacon vector
	bool canAccept=TRUE; // set when mote can accept another child...
	bool inserted; //set when mote is inserted in network	

	message_t packet;
	bool locked;
	bool busy;
	uint16_t counter = 0;
  
  	event void Boot.booted() 
	{
    		//call AMControl.start();
		myID = TOS_NODE_ID;				//myID= TOS_LOCAL_ADDRESS;
		atomic
		{		
			user_leds = 0;
		}		
		//interrupt interface yet to be added
		 		
		atomic
    		{
	        	call MSP430Interrupt.disable();
      			call MSP430GeneralIO.makeInput();
      			call MSP430GeneralIO.selectIOFunc();
      			call MSP430Interrupt.edge(TRUE);
      			call MSP430Interrupt.clear();
      			call MSP430Interrupt.enable();
    		} 
		
		switch(myID)
		{
			case 0:
				master=TRUE;
				chooseFather=5;
				break;
			default:
				slave=TRUE;
				chooseFather=0;
				break;
		}
		//initialize all vector
		for  (i =0 ; i <MAX_SLAVE; i++){
			beaconVector[i]=0;
			slaveVector[i].slave=0;
			slaveVector[i].posInBeacon=0;
			vectorLQI[i]=0;
		}
		idToControl=0;
		positionFather=0;
		nServedSlave=0;
		nRegisteredSlave=0;
		
		call Radio.start();
		//call HumidityControl.start();
		//call RivControl.start();  /****** EXPANSION  SWITCH ******/
		call Timer0.startPeriodic(TIMER_WAKEUP);
		/*
		atomic
       		{
	    
        		call MSP430Interrupt.clear();
        		call MSP430Interrupt.enable();
       		}
       		*/
		
  	}

	/*
	* Void sendData(): task that send data message 
	*
	*/
	
	task void sendData()
	{
		beaconMsgPtr p;
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));	//p=(beaconMsgPtr) msg.data;
		if(fila2){
			call Leds.led2Toggle();     /*   per il test*/
		}
		//Sending data printf
		printf("Sending data sendData()\n");
		/*
		for(j=0;j<10;j++)
		{
			printf("%x ",msg.header[j]);
		}*/
		printf("Payload:");
		for(j=0;j<28;j++)
		{
			printf("%x ",msg.data[j]);
		}
		printf("\n");
		//printf ends
		call Leds.led2On();   
		if (call AMSend.send(AM_BROADCAST_ADDR, &msg, sizeof(beaconMsg)) == SUCCESS) 
		{
        		busy = TRUE;
      		}
		atomic
		{	  	
			user_leds++; 
			if(user_leds==2)
			{  
				call Leds.led1Off();			//call Leds.greenOff();
				call Leds.led0Off();			//call Leds.redOff();	
				atomic
				{	
				//	p->stato=0;
			 	}
			}
		}
		call Leds.led2Off();   
		return;
	}

	/*
	*  Void masterTask(): only the master executes this task where sends beacon message 
						  every TIME_WAKEUP milliseconds.
	*/
	task void masterTask()
	{
		beaconMsgPtr p;
		uint16_t nextBeaconTime;
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));	//p=(beaconMsgPtr) msg.data;
		nextBeaconTime=nextBeacon;
		atomic{
			p->sndId= myID;
			for  (i =0 ; i <MAX_SLAVE; i++){
				p->beaconVector[i] = beaconVector[i];
				//printf("beaconVector[%d]=%d\n",i,beaconVector[i]);
			}
			p->nextBeaconTime = nextBeaconTime;
		}
		nextBeacon= nextBeacon - TIMER_WAKEUP;
		if(nextBeacon==0){
			nextBeacon=TIME_BEACON;
		}
		//sending data printf starts
		printf("Sending data printf\n");
		/*printf("\n Header is as follows : \n");
		for(j=0;j<sizeof(message_header_t);j++)
		{
			printf("%x ",msg.header[j]);
		}*/
		printf("\n Data is as follows : \n");
		for(j=0;j<28;j++)
		{
			printf("%x ",msg.data[j]);
		}
		//printf ends
		if (call AMSend.send(AM_BROADCAST_ADDR, &msg, sizeof(beaconMsg)) == SUCCESS) 
		{
        		busy = TRUE;
      		}
		call Leds.led0Toggle();							//call Leds.redToggle();
		return;
	}
	
	
	/**
	*  slaveTask(): only the slave executes this task.
	*               it considers every situation in which a mote could be if it is attached 
					to master or another mote
	*/
	task void slaveTask()
	{
		uint8_t maxLQI;
		uint16_t time;
		beaconMsgPtr p,r;
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));	//p=(beaconMsgPtr) msg.data;
		r = (beaconMsgPtr)(call Packet.getPayload(&buf, sizeof(beaconMsg)));	//r=(beaconMsgPtr) buf.data;
		if(waitingAnotherChild)
		{
			if(nServedSlave>0 && nServedSlave!=nRegisteredSlave)
			{
				if((slaveVector[nServedSlave].posInBeacon - slaveVector[(nServedSlave-1)].posInBeacon)==1)
				{
					waitingAnotherChild=TRUE;
					call Timer0.stop();
					call Timer0.startOneShot(TIMER_WAKEUP);
					nServedSlave++;
				}
			}
			else
			{
				waitingAnotherChild=FALSE;
				waitingSon=FALSE;
				//call Leds.greenToggle();
			}
		}
		
		if(waiting)
		{
			waiting=FALSE;
		}
		printf("\nSlaveTASK\n");
		if(canSend)
		{
		  printf("\nposso inviare\n");
			call Radio.start();
			atomic{
				p->sndId=myID;
				p->nextBeaconTime=r->nextBeaconTime;
				
				p->myfather=0;
			}
			call Temperature.read(); //reading temperature interface
			canSend=FALSE;
			call Timer0.stop();
			call Timer0.startOneShot(TIMER_WAIT);
			waiting=TRUE;
		}
		if(servicesSlave){
		printf("\nservicesSlave\n");
			call Radio.start();
			servicesSlave=FALSE;
		//	call Leds.greenToggle();
			waitingAnotherChild=TRUE;
			call Timer0.stop();
			call Timer0.startOneShot(TIMER_WAKEUP);
		}
	
		if (waitingFather){
			call Radio.start();
			waitingFather=FALSE;
			printf("\n waitingFather \n");
		}
		if (synchronized){
			call Radio.start();
			atomic{
				p->sndId=myID;
				p->myfather=positionFather;
			}
			call Temperature.read();
			call Timer0.stop();
			time=(positionFather-myIndex)*TIMER_WAKEUP -TIMER_WAKEUP;
			call Timer0.startOneShot(time);
			synchronized=FALSE;
			waitingFather=TRUE;
			
			printf("\n synchronized \n");
		}
		
		if(chooseFather==1){
		printf("\n chooseFather \n");
		
			maxLQI=0;
			for (i=0;i<MAX_SLAVE;i++){
				if(vectorLQI[i]>maxLQI){
					maxLQI=vectorLQI[i];
					positionFather=i;
				}
			}
			chooseFather=2;
			atomic{
				for  (i =0 ; i <MAX_SLAVE; i++){
				if(r->beaconVector[i]==0){
					r->beaconVector[i]=myID;
					break;
					}
				}
				for  (i =0 ; i <MAX_SLAVE; i++){
					beaconVector[i]=r->beaconVector[i];
					p->beaconVector[i]=beaconVector[i];
				}
				
				p->sndId=myID;
			}
			fila2=TRUE;
			fila1=FALSE;
			call Timer0.stop();
			fatherFind=TRUE;
		}
	}


	/*
	* Void replayBeacon(): task executes from slaves attacched to base station
	*					   Used for replay to first beacon message 
	*/
	task void replayBeacon()
	{
		beaconMsgPtr p,r;
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));	//p=(beaconMsgPtr) msg.data;
		r = (beaconMsgPtr)(call Packet.getPayload(&buf, sizeof(beaconMsg)));	//r=(beaconMsgPtr) buf.data;
		for(i=MAX_SLAVE;i>0;i--)
		{
			if (r->beaconVector[i-1]==0)
			{
				atomic{
					r->beaconVector[i-1]=myID;
				}
				break;
			}
		}
		atomic
		{
			for(i=0;i<MAX_SLAVE;i++)
			{
					beaconVector[i]=r->beaconVector[i];
					p->beaconVector[i]=beaconVector[i];
			}
			p->sndId=myID;
			p->nextBeaconTime=r->nextBeaconTime;
			p->myfather=0;
		}
		fila1=TRUE;
		fila2=FALSE;
		//sending data printf starts
		printf("\n\nSending data printf\n");
		printf("Header is as follows : \n");
		/*for(j=0;j<15;j++)
		{
			printf("%x ",msg.header[j]);
		}*/
		printf("\nDATI:");
		for(j=0;j<28;j++)
		{
			printf("%x ",msg.data[j]);
		}
		//printf ends
		if (call AMSend.send(AM_BROADCAST_ADDR, &msg, sizeof(beaconMsg)) == SUCCESS) 
		{
        		busy = TRUE;
      		}
		
		return;
	}
	

	/*
	* Void fileBeacon(): task executes to Base Station when receive any packet
	*/	
	
	task void fileBeacon()
	{
		beaconMsgPtr p,r;
		//uint8_t i;
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));	//p=(beaconMsgPtr) msg.data;
		r = (beaconMsgPtr)(call Packet.getPayload(&buf, sizeof(beaconMsg)));	//r=(beaconMsgPtr) buf.data;
		atomic
		{
			for(i=0;i<MAX_SLAVE;i++)
			{
				if(beaconVector[i]==0 && r->beaconVector[i]!=0)
				{
					beaconVector[i] = r->beaconVector[i];
				}
				p->beaconVector[i]=beaconVector[i];
			}
		}
		//call DataMsg.send(TOS_UART_ADDR,sizeof(beaconMsg), &(buf)); 
		//replacement of datemsg.send on TOS_UART
		/*printf("\n Header is as follows : \n");
		for(j=0;j<15;j++)
		{
			printf("%x ",buf.header[j]);
		}
		printf("\n Data is as follows : \n");
		for(j=0;j<28;j++)
		{
			printf("%x ",buf.data[j]);
		}*/
	}


	/*
	* Void WaitSlave(): task executes from every mote that is attacched to Base station
	*
	*/
	
	task void waitSlave()
	{
		bool presente;
		uint16_t time;
		presente = FALSE;
		if(nRegisteredSlave==0)
		{
			canSend=TRUE;
			time=nextBeacon + (myIndex*TIMER_WAKEUP);
			call Timer0.stop();
			call Timer0.startOneShot(time);
			return;
		}
		if(justRegistered)
		{
			forward=TRUE;
			canSend=TRUE;
			time=nextBeacon + ((myIndex)*TIMER_WAKEUP);
			call Timer0.stop();
			call Timer0.startOneShot(time);
			justRegistered=FALSE;
			return;
		}
		if(nServedSlave==nRegisteredSlave)
		{
			forward=TRUE;
			canSend=TRUE;
			time=(myIndex-slaveVector[(nServedSlave-1)].posInBeacon)*TIMER_WAKEUP-TIMER_WAIT ;
			call Timer0.stop();
			call Timer0.startOneShot(time);
			nServedSlave=0;
			return;
		}
		if(nServedSlave==0)
		{
			time=nextBeacon + ((slaveVector[nServedSlave].posInBeacon)*TIMER_WAKEUP);
			servicesSlave=TRUE;
			waitingSon=TRUE;
			call Timer0.stop();
			call Timer0.startOneShot(time);
			nServedSlave++;
			return;
		}
		else
		{
			time=((slaveVector[nServedSlave].posInBeacon - slaveVector[(nServedSlave-1)].posInBeacon)*TIMER_WAKEUP);
			servicesSlave=TRUE;
			waitingSon=TRUE;
			call Timer0.stop();
			call Timer0.startOneShot(time);
			nServedSlave++;
			return;
		}
		
	}


	/*
	* TOS_MsgPtr ReceiveMyMsg.receive(TOS_MsgPtr m): this event rise up when receive a new message
	*/

	
	event message_t* Receive.receive(message_t* bufPtr,void* payload, uint8_t len) 
	{
		bool trovato;
		bool trovatoSlave;
		bool altroSlave;
		uint16_t time;
		uint8_t posInBeacon;
		beaconMsgPtr p,r;
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));	//p=(beaconMsgPtr) msg.data;
		
		buf=*bufPtr;
		r = (beaconMsgPtr)(call Packet.getPayload(&buf, sizeof(beaconMsg)));	//r=(beaconMsgPtr) buf.data;
		//receiving data printf starts
		printf("\n\nReceiving data printf=%d\n",sizeof(beaconMsg));
		/*printf("Header is as follows : \n");
		for(j=0;j<10;j++)
		{
			printf("%x ",bufPtr->header[j]);
		}
		*/
		printf("Data is as follows : \n");
		for(j=0;j<28;j++)
		{
			printf("%x ",bufPtr->data[j]);
		}
		//printf ends
		
		
		trovato=FALSE;
		trovatoSlave=FALSE;
		altroSlave=FALSE;
		if (slave)
		{
			if(r->sndId == 0)
			{
				if(waitingSon==FALSE)
				{
					for(i=0;i<MAX_SLAVE;i++)
					{
						if (r->beaconVector[i]==myID)
						{
							trovato=TRUE;
							break;
						}
					}
					if(!trovato)
					{
						post replayBeacon(); /* manda in esecuzione un task in maniera asincrona (continuando l`elaborazione) da replayBeacon() */
						printf("\n replayBeacon\n ");
					}
					else
					{
					  printf("\n ELSE replayBeacon\n ");
						if(toControl)
						{
							atomic
							{
								for(i=0;i<MAX_SLAVE;i++)
								{
									if(r->beaconVector[i]==idToControl)
									{
										toControl=FALSE;
										canAccept=TRUE;
						//				call Leds.redToggle();
										break;
									}
								}
							}
							if(toControl)
							{
								atomic
								{
									for(i=0;i<MAX_SLAVE;i++)									{									
										beaconVector[i] = r->beaconVector[i];
										if(beaconVector[i]==0 && inserted==FALSE)
										{
											beaconVector[i]=idToControl;
											inserted=TRUE;
										}
										p->beaconVector[i]=beaconVector[i];
									}
									p->sndId=idToControl;
									p->temp=0;
									p->hum=0;
									
									//p->stato=0;
									p->light_TSR=0;
									p->light_PAR=0;
									
									p->myfather=myID;
									p->nextBeaconTime=r->nextBeaconTime;
									
								}
								//sending data printf starts
								printf("Sending data printf\n");
								printf("\n Header is as follows : \n");
								for(j=0;j<15;j++)
								{
									printf("%x ",msg.header[j]);
								}
								printf("\n Data is as follows : \n");
								for(j=0;j<28;j++)
								{
									printf("%x ",msg.data[j]);
								}
								//printf ends
								if (call AMSend.send(0, &msg, sizeof(beaconMsg)) == SUCCESS) 
								{
        								busy = TRUE;
      								}
							}
						}
						else
						{
							atomic
							{
								p->sndId=myID;
								for(i=0;i<MAX_SLAVE;i++)
								{
									if(beaconVector[i]==0 && r->beaconVector[i]!=0)
										beaconVector[i] = r->beaconVector[i];
									if(beaconVector[i]==myID)
									{
										myIndex = i;
									}
									p->beaconVector[i]=beaconVector[i];
								}
								p->nextBeaconTime=r->nextBeaconTime;
								p->temp=0;
								p->hum=0;
								//p->stato=0;
								p->light_TSR=0;
								p->light_PAR=0;
								p->myfather=0;
								nextBeacon=p->nextBeaconTime;
							}
							if(forward==TRUE)
							{
								forward=FALSE;
								//sending data printf starts
								printf("Sending data printf\n");
								printf("\n Header is as follows : \n");
								for(j=0;j<15;j++)
								{
									printf("%x ",msg.header[j]);
								}
								printf("\n Data is as follows : \n");
								for(j=0;j<28;j++)
								{
									printf("%x ",msg.data[j]);
								}
								//printf ends
								if (call AMSend.send(AM_BROADCAST_ADDR, &msg, sizeof(beaconMsg)) == SUCCESS) 
								{
        								busy = TRUE;
      								}
					//			call Leds.yellowToggle();
								
								return bufPtr;
							}		
							if(waiting==FALSE)
							{
								call Radio.stop();
								post waitSlave();
								return bufPtr;
							}
						}
						
					}
				}
			}
			else
			{
				if(fila1)
				{
					if(r->myfather==myID)
					{							
						atomic
						{
							for(i=0;i<MAX_SLAVE;i++)
							{
								if(r->sndId==slaveVector[i].slave)
								{
									trovatoSlave=TRUE;
						//			call Leds.redToggle();
									break;								
								}
							}
						}
						if(trovatoSlave==FALSE)
						{
							atomic
							{
								for(i=0;i<MAX_SLAVE;i++)
								{
									if(slaveVector[i].slave==0)
									{
										slaveVector[i].slave=r->sndId;
										posInBeacon=i;
										if(nRegisteredSlave==0)
										{
											justRegistered=TRUE;
										}
										nRegisteredSlave++;
										
										break;
									}
								}
							}
							atomic
							{
								for(i=0;i<MAX_SLAVE;i++)
								{
									if(beaconVector[i]==0)
									{
										beaconVector[i]=r->sndId;
										slaveVector[posInBeacon].posInBeacon=i;
										break;	
									}
								}	
								for(i=0;i<MAX_SLAVE;i++)
								{
										p->beaconVector[i]=beaconVector[i];
								}
								p->sndId=r->sndId;	
								p->temp=0;
								p->hum=0;
							//	p->stato=0;
								p->light_TSR=0;
								p->light_PAR=0;
								p->myfather=r->myfather;
								p->nextBeaconTime=r->nextBeaconTime;
								idToControl=r->sndId;
								toControl=TRUE;
								canAccept=FALSE;
								inserted=FALSE;
							}
							//sending data printf starts
							printf("Sending data printf\n");
							printf("\n Header is as follows : \n");
							for(j=0;j<15;j++)
							{
								printf("%x ",msg.header[j]);
							}
							printf("\n Data is as follows : \n");
							for(j=0;j<28;j++)
							{
								printf("%x ",msg.data[j]);
							}
							//printf ends
							if (call AMSend.send(AM_BROADCAST_ADDR, &msg, sizeof(beaconMsg)) == SUCCESS) 
							{
        							busy = TRUE;
      							}
						}
						else
						{
							atomic
							{
								p->sndId=r->sndId;	
								p->nextBeaconTime=r->nextBeaconTime;
								for(i=0;i<MAX_SLAVE;i++)
								{
									p->beaconVector[i]=r->beaconVector[i];
								}
								p->temp=r->temp;
								p->hum=r->hum;
								//p->stato=r->stato;
								p->light_TSR=r->light_TSR;
								p->light_PAR=r->light_PAR;
								p->myfather=r->myfather;
							}
							//sending data printf starts
								printf("Sending data printf\n");
								printf("\n Header is as follows : \n");
								for(j=0;j<15;j++)
								{
									printf("%x ",msg.header[j]);
								}
								printf("\n Data is as follows : \n");
								for(j=0;j<28;j++)
								{
									printf("%x ",msg.data[j]);
								}
								//printf ends
							if (call AMSend.send(0, &msg, sizeof(beaconMsg)) == SUCCESS) 
							{
        							busy = TRUE;
      							}
						}
					}
				}
				else
				{
					if(fila2)
					{
						if(present==FALSE)
						{
							if(r->sndId==positionFather)
							{
								for(i=0;i<MAX_SLAVE;i++)
								{
									if (r->beaconVector[i]==myID)
									{
										trovato=TRUE;
										myIndex=i;
										break;
									}
								}
								if(!trovato)
								{
									call Timer0.stop();
									atomic
									{
										for(i=0;i<MAX_SLAVE;i++)
										{
											p->beaconVector[i]=r->beaconVector[i];
											beaconVector[i]=r->beaconVector[i];
										}
										p->sndId= myID;
										p->temp=0;
										p->hum=0;
									//	p->stato=0;
									        p->light_TSR=0;
									        p->light_PAR=0;
										p->myfather=positionFather;
										p->nextBeaconTime=r->nextBeaconTime;
									}
									//sending data printf starts
									printf("Sending data printf\n");
									printf("\n Header is as follows : \n");
									for(j=0;j<15;j++)
									{
										printf("%x ",msg.header[j]);
									}
									printf("\n Data is as follows : \n");
									for(j=0;j<28;j++)
									{
										printf("%x ",msg.data[j]);
									}
									//printf ends
									if (call AMSend.send(AM_BROADCAST_ADDR, &msg, sizeof(beaconMsg)) == SUCCESS) 
									{	
        									busy = TRUE;
      									}
								}
								else
								{
									if(r->temp==0 && r->hum==0)
									{
										atomic
										{
											for(i=0;i<MAX_SLAVE;i++)
											{
												p->beaconVector[i]=r->beaconVector[i];
												beaconVector[i]=r->beaconVector[i];
											}
											time=r->nextBeaconTime + (myIndex*TIMER_WAKEUP);
										}
										call Timer0.stop();
										call Timer0.startOneShot(time);
										present=TRUE;
										synchronized=TRUE;
										call Radio.stop();
										return bufPtr;
									}
									
								}
							}
						}
						else
						{
							atomic
							{
								for(i=0;i<MAX_SLAVE;i++)
								{
									if (r->beaconVector[i]==myID)
									{
										myIndex=i;
										break;
									}
								}
							}
							if(r->sndId==positionFather)
							{
								if(r->temp==0 && r->hum==0)
								{
									atomic
									{
										for(i=0;i<MAX_SLAVE;i++)
										{
											p->beaconVector[i]=r->beaconVector[i];
											beaconVector[i]=r->beaconVector[i];
										}
										time=r->nextBeaconTime + (myIndex*TIMER_WAKEUP);
									}
									call Timer0.stop();
									call Timer0.startOneShot(time);
									synchronized=TRUE;
									call Radio.stop();
								//	call Leds.greenToggle();
								}
							}									
						}
					}
					else
					{ 			
						for(i=0;i<MAX_SLAVE;i++)
						{
							if (r->beaconVector[i]==myID)
							{
								trovato=TRUE;
								break;
							}
						}
						if(!trovato)
						{
							if(chooseFather==0)
							{
								call Timer0.stop();
								call Timer0.startOneShot(TIMER_SCANNER);
								chooseFather=1;
					//			call Leds.yellowToggle();
							}
							if(r->myfather==0)
							{
								//vectorLQI[r->sndId]= m->lqi;
							}							
						}
					}
				}
			}
		}
		else
		{
			post fileBeacon();
		}
		return bufPtr;
	}

	/************************************
	* Timer0 fire event
	************************************/	


  	event void Timer0.fired()
	{
		if (master)
		{
			post masterTask();
		}
		else
		{
			post slaveTask();
		}
		
	}


	/*
	* event void MSP430Interrupt.fired() this event set user command
	*	
	*/
	
	 async event void MSP430Interrupt.fired()
	 {
	 }	
	
	event void Notify.notify( button_state_t state ) 
  	{
    		beaconMsgPtr p;
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));
   		user_leds=0;
   		
   		 if ( state == BUTTON_PRESSED) {
   		 call Leds.led1Toggle(); 
		/*
		      switch(p->stato) 
		{
			case UP:
		        	call Leds.led1On(); 
				call Leds.led0Off(); 
				atomic
				{
					p->stato=DOWN;
				}
				break;

			case DOWN:  
				call Leds.led1Off();
				call Leds.led0On();
				atomic
				{
					p->stato=UP;
				}
				break;
			case 0:
				atomic
				{
					p->stato=UP;	
				}	
			        call Leds.led0On(); 
				break;

			default: 
				call Leds.led0Off(); 
			        call Leds.led1Off(); 
				atomic
				{	
				         p->stato=0;
				}	
				break;
		}  */
		
		
		
		    } else if ( state == BUTTON_RELEASED) {
		    
		    call Leds.led1Off(); 
		      
		    } 
   		
   		
		
		/*     signal UserButton.fired();
    		 debounce
	 	 atomic
    		{	
        		call MSP430Interrupt.clear();
    
		}*/
  	} 


	/*
	* result_t Humidity.dataReady(uint16_t data): this event rise up when humidity data is ready
	*	after set field humidity, the mote send data.
	*/
	
		
	event void  Humidity.readDone(error_t r,uint16_t data) 
	{
		beaconMsgPtr p;
		if (r == SUCCESS){
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));
		atomic
		{
			p->hum = data;
		}
	
		call TSR.read();    // luce TSR  */
		printf("Humidity letta:%02x\n",data);
               }
               else
               {
               printf("ERRORE Humidity\n");
               }
	}

	
	/*
	* event result_t Temperature.dataReady(uint16_t data):this event rise up when temperature data is ready
	* after set field temperature, the mote call Humidity.getData() for get humidity data.
	*/
  
	
	event void Temperature.readDone(error_t r,uint16_t data) 
	{
		beaconMsgPtr p;
		
		
		if (r == SUCCESS){
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));
		
		atomic
		{
			p->temp = data ;
		}
		printf("Temperature letta:%02x\n",data);
		call Humidity.read(); // chiama async event result_t Humidity.dataReady 
		}
		else
               {
               printf("ERRORE Temperature\n");
               }
		
	} 
	
	 
     	
	/* HamamatsuC data ready event handler for light_TSR sensor*/
    	
	event void TSR.readDone(error_t r,uint16_t data) 
	{
		// display(7-((data>>7) &0x7));   
		beaconMsgPtr p;
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));
		atomic
		{
			p->light_TSR = data ;
		}    
        	call PAR.read();
        	printf("TSR letta:%02x\n",data); 			
		//return SUCCESS;
  	}
	
	
	/* HamamatsuC data ready event handler for light_PAR sensor*/
	
		
	event void PAR.readDone(error_t r,uint16_t data) 
	{
		// display(7-((data>>7) &0x7)); 	
		beaconMsgPtr p;
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));
		atomic
		{
			p->light_PAR = data;
		}    
			
		//call RIV.getData(); 	  // EXPANSION  SWITCH 
			call AccX.read();
		
		
		printf("PAR letta:%02x\n",data); 
  	}
    
	
	/* Acc_X*/
	
	event void AccX.readDone(error_t r,uint16_t data) 
	{
			
		beaconMsgPtr p;
		
		if (r == SUCCESS){
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));
		atomic
		{
			p->ADXL321_ACC_Axis_X = data;
		}    
			
		
			call AccY.read();
		
		
		printf("AccX letta:%02x\n",data); 
		}
		else
		{
		 printf(" AccX ERRORE \n"); 
		}
  	}
	
	/* Acc_Y*/
	
	event void AccY.readDone(error_t r,uint16_t data) 
	{
			
		beaconMsgPtr p;
		
		if (r == SUCCESS){
		p = (beaconMsgPtr)(call Packet.getPayload(&msg, sizeof(beaconMsg)));
		atomic
		{
			p->ADXL321_ACC_Axis_Y = data;
		}    
			
		
			post sendData();
		
		
		printf("AccY letta:%02x\n",data); 
		}
		else
		{
		 printf(" AccY ERRORE \n"); 
		}
  	}
	
	
	
	
	
	
	
	
		
	/****** EXPANSION  SWITCH ******/
	
	/*	

	async event result_t RIV.dataReady(uint16_t data) 
	{
		beaconMsgPtr p;
		p=(beaconMsgPtr) msg.data;
		atomic
		{
			p->detach = data;
		}    
		post sendData();
		return SUCCESS;
  	}
	
	*/
	
	
	/*
	
	event result_t TemperatureError.error(uint8_t token) {
		return SUCCESS;
	}
	
	event result_t HumidityControl.initDone() {
		return SUCCESS;
	}
	event result_t HumidityControl.startDone() {
		call HumidityError.enable();
		call TemperatureError.enable();
		return SUCCESS;
	}
	event result_t HumidityControl.stopDone() {
		call HumidityError.disable();
		call TemperatureError.disable();
		return SUCCESS;
	}
	
	*/

	event void Radio.startDone(error_t err) 
	{
    		if (err == SUCCESS) 
		{
      
    		}
    		else 
		{
      
    		}
  	}

  	event void Radio.stopDone(error_t err) 
	{
    
  	}
  
  		

  	event void AMSend.sendDone(message_t* bufPtr, error_t error) 
	{
    		if(&packet == bufPtr) 
		{
	        	locked = FALSE;
    		}
	 	else
		{
	 	 
  		}
		//return bufPtr;
	}

}








