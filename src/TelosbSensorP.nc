
generic module TelosbSensorP( uint16_t senseTimeLimit )  {

	provides interface TelosbBuiltinSensors;

	uses {
		interface Read<uint16_t> as ReadTemperature;
		interface Read<uint16_t> as ReadHumidity;
		interface Read<uint16_t> as ReadLight;
		interface Read<uint16_t> as ReadBattery;
	}
	uses interface Timer<TMilli> as SensingDelayTimer;
}
implementation {


	// SENSING_DELAY_X : the period of time used to read all sensors 
	enum {
		SENSING_DELAY_1 = 25, //ms
		SENSING_DELAY_2 = 50, //ms	
		SENSING_DELAY_3 = 75, //ms	
		SENSING_DELAY_4 = 100, //ms						
	};

	uint16_t sensingDelay = senseTimeLimit;

	bool TEMPERATURE_OK = FALSE;
	bool HUMIDITY_OK    = FALSE;
	bool LIGHT_OK       = FALSE;
	bool BATT_OK        = FALSE;

	uint16_t temperature = 0xffff;
	uint16_t humidity    = 0xffff;
	uint16_t light       = 0xffff;
	uint16_t battery     = 0xffff;	

	command error_t TelosbBuiltinSensors.readTemperature() {
		return ( call ReadTemperature.read() );
	}
	event void ReadTemperature.readDone( error_t err, uint16_t data ) {	
		if( err  == SUCCESS ) {
			TEMPERATURE_OK = TRUE;				
			temperature = data;
		} else {
			temperature = 0xffff;			
		}		
		signal TelosbBuiltinSensors.readTemperatureDone( err, data );
	}


	command error_t TelosbBuiltinSensors.readHumidity() {
		return ( call ReadHumidity.read() );
	}
	event void ReadHumidity.readDone( error_t err, uint16_t data ) {
		if( err == SUCCESS) {
			HUMIDITY_OK = TRUE;
			humidity = data;
		} else {
			humidity = 0xffff;
		}
		signal TelosbBuiltinSensors.readHumidityDone( err, data );
	}	


	command error_t TelosbBuiltinSensors.readLight() {
		return ( call ReadLight.read() );
	}
	event void ReadLight.readDone( error_t err, uint16_t data ) {
		if( err == SUCCESS ) {
			LIGHT_OK = TRUE;
			light = data;
		} else {
			light = 0xffff;
		}
		signal TelosbBuiltinSensors.readLightDone( err, data );
	}


	command error_t TelosbBuiltinSensors.readBattery() {
		return ( call ReadBattery.read() );
	}
	event void ReadBattery.readDone( error_t err, uint16_t data ) {
		if( err == SUCCESS ) {
			BATT_OK = TRUE;
			battery = data;
		} else {
			battery = 0xffff;
		}
		signal TelosbBuiltinSensors.readBatteryDone( err, data );
	}


	/**
	* If the overall four readings are concerned in your app, you can 
	* use the first return statement.
	*/
	command error_t TelosbBuiltinSensors.readAllSensors() {
		bool flag1, flag2, flag3, flag4;

		call SensingDelayTimer.startOneShot( sensingDelay );
		flag1 = call ReadTemperature.read();
		flag2 = call ReadHumidity.read();
		flag3 = call ReadLight.read();
		flag4 = call ReadBattery.read();

		//return ( flag1 && flag2 && flag3 && flag4 );
		return TRUE;  
	}

	event void SensingDelayTimer.fired() {
		signal TelosbBuiltinSensors.readAllDone( TEMPERATURE_OK, temperature,
												 HUMIDITY_OK, humidity,
												 LIGHT_OK, light, 
												 BATT_OK, battery ); 
		call SensingDelayTimer.stop();
	}

}