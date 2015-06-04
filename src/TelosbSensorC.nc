/**
* created: Guodong Sun, 05/27/2014
* modified:
*
**/

generic configuration TelosbSensorC(uint16_t senseTimeLimit ) {
	provides {
		interface TelosbBuiltinSensors;
	}
}
implementation {

	components new TelosbSensorP( senseTimeLimit ) ;
	TelosbBuiltinSensors = TelosbSensorP.TelosbBuiltinSensors;

  	components new SensirionSht11C()    as TempHumiSensor;  
  	components new HamamatsuS1087ParC() as LightSensor;
  	components new VoltageC()			as BatterySensor;   

  	TelosbSensorP.ReadTemperature -> TempHumiSensor.Temperature;
  	TelosbSensorP.ReadHumidity    -> TempHumiSensor.Humidity;
  	TelosbSensorP.ReadLight       -> LightSensor;
  	TelosbSensorP.ReadBattery     -> BatterySensor;

  	components new TimerMilliC() ;
  	TelosbSensorP.SensingDelayTimer -> TimerMilliC;
}