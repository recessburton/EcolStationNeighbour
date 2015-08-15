/**
 Copyright (C),2014-2015, YTC, www.bjfulinux.cn
 Copyright (C),2014-2015, ENS Group, ens.bjfu.edu.cn
 Created on  2015-06-04 15:10
 
 @author: ytc recessburton@gmail.com
 @version: 0.8
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>
 **/

#include <Timer.h>
#include "EcolStationNeighbour.h"

module EcolStationNeighbourP {
	provides interface EcolStationNeighbour;  
	
	uses interface Timer<TMilli> as Timer0;
	uses interface Timer<TMilli> as Timer1;
	uses interface Packet;
	uses interface AMPacket;
	uses interface AMSend;
	uses interface Receive;
	uses interface SplitControl as RadioControl;
	uses interface StdControl as RoutingControl;
	uses interface RootControl;
	uses interface Send;
	uses interface Receive as CTPReceive;
	uses interface TelosbBuiltinSensors;
	
}

implementation {

	NeighbourUnit neighbourSet[3*MAX_NEIGHBOUR_NUM];
	nx_NeighbourUnit nx_neighbourSet[MAX_NEIGHBOUR_NUM];
	message_t pkt,packet;
	uint8_t helloMsgCount = 0;
	volatile uint8_t neighbourNumIndex = 0;//邻居数目，>从0开始!<<<<<<
	uint16_t temper = 0;
	uint16_t humid = 0;
	uint16_t light = 0;
	uint16_t battery = 0;
	bool firstread = TRUE;
	bool preambleTimer = TRUE;
	uint8_t preambleCount = 0;

	task void helloMsgSend() {			//hello包发送，用于链路质量评估，>任务，调用后立即返回，函数异步执行<
		NeighbourMsg * btrpkt = (NeighbourMsg * )(call Packet.getPayload(&pkt, sizeof(NeighbourMsg)));
		if(btrpkt == NULL) {
			return;
		}
		btrpkt->dstid = 0xFF;
		btrpkt->sourceid = (nx_int8_t)TOS_NODE_ID;
		call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(NeighbourMsg));
	}
	
	void sortNodes(int left, int right){	// >非任务，调用后进入函数执行，结束后才返回，调用时为原子调用，其间不可中断<
		//邻居节点集中按照链路质量快速排序
		int i, j;
		NeighbourUnit *temp, *t;
		
		if(left > right) 
			return;	
			
		temp = (NeighbourUnit*)malloc(sizeof(NeighbourUnit));
		memcpy(temp, &neighbourSet[left], sizeof(NeighbourUnit));
		i = left;
		j = right;
		while(i != j) {
			while(neighbourSet[j].linkquality <= temp->linkquality && i < j)
				j --;
			while(neighbourSet[i].linkquality >= temp->linkquality && i < j)
				i ++;	
				
			if( i < j ) {
				t= (NeighbourUnit*)malloc(sizeof(NeighbourUnit));
				memcpy(t, &neighbourSet[i], sizeof(NeighbourUnit));
				memset(&neighbourSet[i], sizeof(NeighbourUnit),0);
				memcpy(&neighbourSet[i], &neighbourSet[j],  sizeof(NeighbourUnit));
				memset(&neighbourSet[j], sizeof(NeighbourUnit),0);
				memcpy(&neighbourSet[j], t,   sizeof(NeighbourUnit));	
				free(t);
			}
		}
		memset(&neighbourSet[left], sizeof(NeighbourUnit),0);
		memcpy(&neighbourSet[left], &neighbourSet[i], sizeof(NeighbourUnit));
		memset(&neighbourSet[i], sizeof(NeighbourUnit),0);
		memcpy(&neighbourSet[i], temp, sizeof(NeighbourUnit));
		free(temp);
		
		sortNodes(left, i-1);
		sortNodes(i+1, right);
	}
	
	void convertNX(){
		int i;
		memset(nx_neighbourSet, MAX_NEIGHBOUR_NUM,0);
		atomic{
			for(i = 0; i<(MAX_NEIGHBOUR_NUM < neighbourNumIndex ? MAX_NEIGHBOUR_NUM : neighbourNumIndex); i++ ){
				//将邻居集转换为网络类型
				nx_neighbourSet[i].nodeid = (nx_uint8_t)neighbourSet[i].nodeid;
				nx_neighbourSet[i].linkquality = (nx_uint8_t)(neighbourSet[i].linkquality*100);
			}
		}
	}
	
	task 	void estLinkQ(){					// >任务，计算邻居集中每个节点的链路质量，调用后立即返回<
		int i;
		float linkq;
		atomic{
			for(i = 0; i< neighbourNumIndex; i++ ){
				linkq = (float) (neighbourSet[i].recvCount /10.0f);
				neighbourSet[i].linkquality = (linkq>1.0f ? 1.0f : linkq);
			}
		}
		atomic{
			sortNodes(0, neighbourNumIndex);
		}
		convertNX();
	}
	
	event void Timer0.fired() {	//>>>>>>>>>>>>>特别注意Timer0和Timer1两个定时器的启停和配合！！！
		if (helloMsgCount < 10){		//空转10次等待
			helloMsgCount ++;
		}else if(helloMsgCount == 10){	//空转结束，准备发送preamble前导等待节点醒来
			helloMsgCount ++;
			preambleTimer = TRUE;
			call Timer1.startPeriodic(PREAMBLE_PERIOD_MILLI);
		}else if(helloMsgCount < 12){     //空转2s，等待链路评估结束
			helloMsgCount ++;
		}else if(helloMsgCount == 12){	//结束链路评估，计算各个邻居的链路质量，对结果进行排序，网络字节序转换，准备邻居关系报告
			helloMsgCount ++;
			post estLinkQ();
			call Timer1.startPeriodic(NEIGHBOUR_PERIOD_MILLI);	//准备就绪，开始持续的邻居关系报告
		}else if(helloMsgCount < 120){
			helloMsgCount ++;
		}else{													//大于120次，即120s，则重新开始邻居关系评估
			call Timer1.stop();						//暂时停止邻居关系消息的发送
			helloMsgCount = 0;
			//内存中的邻居关系数据清空
			neighbourNumIndex = 0;
			memset(neighbourSet,3*MAX_NEIGHBOUR_NUM,0);
			memset(nx_neighbourSet, MAX_NEIGHBOUR_NUM,0);
		}
	}

	event void AMSend.sendDone(message_t * msg, error_t err) {
	}
	
	void ackMsgSend(uint16_t sourceid) {
		NeighbourMsg * btrpkt1 = (NeighbourMsg * )(call Packet.getPayload(&pkt,sizeof(NeighbourMsg)));
		if(btrpkt1 == NULL) {
			return;
		}
		btrpkt1->dstid = (nx_int8_t)sourceid;
		btrpkt1->sourceid = (nx_int8_t)TOS_NODE_ID;
		call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(NeighbourMsg)) ;
	}
	
	int addSet(uint16_t sourceid){
		int i;
		if(sourceid <= 0 || helloMsgCount <= 10)		//nodeid 错误，或回包过时，作废
			return -1;
		for(i = 0 ; i <= neighbourNumIndex; i++ ){
			if(neighbourSet[i].nodeid - sourceid == 0)
				return i;
			else
				continue;
		}
		//如果执行到此处，表明该节点不在邻居集合中
		neighbourSet[neighbourNumIndex].nodeid = sourceid;
		neighbourSet[neighbourNumIndex].linkquality = 0.0f;
		neighbourSet[neighbourNumIndex].recvCount = 0;
		return ++neighbourNumIndex;
	}
	
	void updateLinkQCount(int nodeindex){
		float linkq;
		int totalhello = helloMsgCount<20?helloMsgCount:20;
		if (nodeindex < 0)
			return;
		neighbourSet[nodeindex].recvCount ++;	
	}

	task void sendPreamble(){
		uint8_t * btrpkt = (uint8_t * )(call Packet.getPayload(&pkt, sizeof(uint8_t)));
		if(btrpkt == NULL) {
			return;
		}
		*btrpkt=0xFE;
		call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(uint8_t));
	}
	
	task void sendMessage(){
		NeiMsg* ctpmsg = (NeiMsg*)call Send.getPayload(&packet, sizeof(NeiMsg));
		ctpmsg -> neighbourNum = (nx_int8_t)(MAX_NEIGHBOUR_NUM < neighbourNumIndex ? MAX_NEIGHBOUR_NUM : neighbourNumIndex);
		ctpmsg -> nodeid = (nx_uint8_t)TOS_NODE_ID;
		ctpmsg -> temp   = temper;
		ctpmsg -> humid = humid;
		ctpmsg -> light     = light;
		ctpmsg -> power = battery;
		memcpy(ctpmsg -> neighbourSet, nx_neighbourSet, sizeof(nx_neighbourSet));
		call Send.send(&packet, sizeof(NeiMsg));
	}

	event message_t * Receive.receive(message_t * msg, void * payload,uint8_t len) {
		int i;
		if(len == sizeof(NeighbourMsg)) {
			NeighbourMsg * btrpkt = (NeighbourMsg * ) payload;
			if(btrpkt->dstid == 0xFF && btrpkt->sourceid!=TOS_NODE_ID){	//接到其它节点发的hello包，回ack包
				ackMsgSend(btrpkt->sourceid);
			}
			else if ( (btrpkt->dstid - TOS_NODE_ID) == 0) {	//接到的是自己的回包，计算链路质量，判断邻居资格
				atomic{
					updateLinkQCount(addSet(btrpkt->sourceid));
				}
			}else{	//其它包，丢弃
			}
		}
		return msg;
	}

	event void RadioControl.startDone(error_t err){
		if(err != SUCCESS){
			call RadioControl.start();
		}else{
			call RoutingControl.start();
		}
	}

	event void RadioControl.stopDone(error_t error){
		call RadioControl.start();
	}

	event void Send.sendDone(message_t *msg, error_t error){
	}

	event message_t * CTPReceive.receive(message_t *msg, void *payload, uint8_t len){
		int i;
		if(len == sizeof(NeiMsg)) {
			NeiMsg * btrpkt = (NeiMsg * ) payload;
		}
		return msg;
	}

	event void Timer1.fired(){
		if(!preambleTimer){												//周期性邻居关系报告（包含各个传感器信息）
			call TelosbBuiltinSensors.readAllSensors();
			return;
		}
		
		if(preambleCount<5){	//发送5个前导消息，确保节点醒来
			preambleCount++;
			post sendPreamble();
		}else if(preambleCount <15){							//发送10次hello消息包，用于链路质量评估
			preambleCount++;
			post helloMsgSend();
		}else if(preambleCount == 15){						//评估结束，暂时停止Timer1,等待Timer0来启动周期性的邻居报告
			preambleCount = 0;
			preambleTimer = FALSE;
			call Timer1.stop();
		}
	}
	
	event void TelosbBuiltinSensors.readBatteryDone(error_t err, uint16_t data){
		// TODO Auto-generated method stub
	}

	event void TelosbBuiltinSensors.readHumidityDone(error_t err, uint16_t data){
		// TODO Auto-generated method stub
	}

	event void TelosbBuiltinSensors.readLightDone(error_t err, uint16_t data){
		// TODO Auto-generated method stub
	}

	event void TelosbBuiltinSensors.readTemperatureDone(error_t err, uint16_t data){
		// TODO Auto-generated method stub
	}

	event void TelosbBuiltinSensors.readAllDone(error_t errT, uint16_t tem, error_t errH, uint16_t humi, error_t errL, uint16_t ligh, error_t errB, uint16_t batt){
		if(firstread){
			firstread = FALSE;
			return;
		}
		temper = tem;
		humid = humi;
		light = ligh;
		battery = batt;
		post sendMessage();	//CTP发送给基站
	}

	command error_t EcolStationNeighbour.startNei(){		//本接口入口点
		call RadioControl.start();
		call Timer0.startPeriodic(TIMER_PERIOD_MILLI);
		call TelosbBuiltinSensors.readAllSensors();					//AD预读，确保以后第一次读取的数值正确
		return TRUE;
	}
	
	command error_t EcolStationNeighbour.restart(){
		firstread = TRUE;
		call RoutingControl.stop();
		call RadioControl.stop();
		return TRUE;
	}
}