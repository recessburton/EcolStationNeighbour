#ifndef ECOL_STATION_NEIGHBOUR_H
#define ECOL_STATION_NEIGHBOUR_H

enum {
	ORWNEIGHBOUR = 5,
	TIMER_PERIOD_MILLI = 256,
	NEIGHBOUR_PERIOD_MILLI = 10240,
	MAX_NEIGHBOUR_NUM = 5
};

typedef nx_struct NeighbourMsg {
	nx_uint8_t dstid;
	nx_uint8_t sourceid;
	//nx_uint8_t EDC;
} NeighbourMsg;

typedef struct NeighbourUnit {
	//注意各成员定义的顺序，以下排序得到本结构体长度为8
	uint8_t recvCount;
	uint16_t nodeid;
	float linkquality;			//精确到小数点后一位
	//uint8_t EDC;
} NeighbourUnit;

typedef nx_struct nx_NeighbourUnit {
	//send的payload最大为20字节，此处尽量减少数据空间
	nx_uint8_t nodeid;
	nx_uint8_t linkquality;	//原始float值扩大100倍
} nx_NeighbourUnit;

typedef nx_struct NeiMsg{   
	//send的payload最大为20字节，此处尽量减少数据空间
	nx_int8_t neighbourNum;
	nx_int8_t nodeid;
	nx_int16_t power;				
	nx_NeighbourUnit neighbourSet[MAX_NEIGHBOUR_NUM];
}NeiMsg;

#endif /* ECOL_STATION_NEIGHBOUR_H */
