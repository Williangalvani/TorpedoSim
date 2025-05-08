![screenshot](./images/screenshot.jpg)

Torped-style AUV simulator for development of a frame on ArduSub.

to use, launch the simulator. and then run the ArduSub code.

```./Tools/autotest/sim_vehicle.py -S 1 -v sub -L RATBeach --model JSON --frame vectored_6dof```

the vectored_6dof frame loads sub-6dof.parm, which is one of the first things we need to modify.

Use Godot 4.4-beta2

															 
				BlueSim manages                              
				Instances of BlueOS                          
				Passing custom ports                         
				for SITL and http comms                      
				(cockpit served on /cockpit)                 
															 
  ┌─────────────┐          ┌───────────────┐                 
  │             ┼─────────►│               │                 
  │  BlueSIM    │          │ BlueOS        │                 
  │             │          │ SITL          │                 
  └──┬──────────┘   ┌──────┼               │                 
	 │              │      └┬────────────▲─┘                 
	 │              │       │Mavlink     │                   
	 │              │       │Telemetry   │Mavlink controls   
	 │        Serves│       │            │                   
	 │              │       │            │                   
	 │              │      ┌▼────────────┼──┐                
	 │              └─────►│                │                
	 │ Game state          │  Cockpit       │                
	 └────────────────────►│                │                
   (same port all clients) │                │                
						   └────────────────┘                
															 
															 
