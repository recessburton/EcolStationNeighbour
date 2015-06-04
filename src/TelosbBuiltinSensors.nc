/**
* created: Guodong Sun, 05/27/2014
* modified:
*
**/

interface TelosbBuiltinSensors {

	/*
	* read the temperature sensor of Telosb.
	* return SUCCESS if the post was successful.
	*/
	command error_t readTemperature();

	/*
	* read the humidity sensor of Telosb
	* return SUCCESS if the post was successful.	
	*/	
	command error_t readHumidity();

	/*
	* read the light sensor of Telosb
	* return SUCCESS if the post was successful.	
	*/	
	command error_t readLight();

	/*
	* read the voltage of Telosb's battery
	* return SUCCESS if the post was successful.	
	*/		
	command error_t readBattery();

	/*
	* read all the above sensors of Telosb
	* what to return is determined in TelosbSensorP	
	*/	
	command error_t readAllSensors();

	event void readTemperatureDone( error_t err, uint16_t data );
	event void readHumidityDone( error_t err, uint16_t data );
	event void readLightDone( error_t err, uint16_t data );
	event void readBatteryDone( error_t err, uint16_t data );	


	/**
	* Signaled when the sensingDelayTimer fires, regardless whether
	* all sensors have been sampled correctly.
	*
	*/
	event void readAllDone( error_t errT, uint16_t temp, 
							error_t errH, uint16_t humi, 
							error_t errL, uint16_t ligh, 
							error_t errB, uint16_t batt  );
}