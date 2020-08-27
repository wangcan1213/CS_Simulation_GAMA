/**
* Name: CityScope Kendall
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Platform. Actually used on 2 different cities.
*/
model CityScope

import "CityScope_main.gaml"


global
{
}

experiment CityScopeMulti type: gui parent: CityScopeMain
{
	init
	{
        create simulation with: [cityScopeCity::"Andorra", minimum_cycle_duration::0.02, cityMatrix::false, angle :: -9.74,center ::{1007,632}, brickSize :: 21.3];
		create simulation with: [cityScopeCity:: "Taipei", minimum_cycle_duration::0.02, cityMatrix::false];
		create simulation with: [cityScopeCity:: "Shanghai", minimum_cycle_duration::0.02, cityMatrix::false];
		create simulation with: [cityScopeCity:: "Lyon", minimum_cycle_duration::0.02, cityMatrix::false];
		create simulation with: [cityScopeCity:: "otaniemi", minimum_cycle_duration::0.02, cityMatrix::false];			
	}

	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <- "volpe" among: ["volpe", "andorra","San_Francisco","Taipei_MainStation","Shanghai"];
	float minimum_cycle_duration <- 0.02;
	output
	{
		display CityScope type: opengl parent: CityScopeVirtual
		{
		}

	}

}



