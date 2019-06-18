# Change Frsky sensor Id

Lua script to change Frsky sensor id from the radio

- Connect the sensors to Rx smartport (does not work with the smartport on the radio)
- Multiple sensors can be connected. Do not connect more than one sensor per type (e.g. two FLVSS) or both will change to the same sensor id
- Once selected the sensor type, the sensor id is read
- Then change the sensor id and long press Menu to update
- It may be needed to repeat the process if the sensor id is not updated
- If telemetry is lost after change id update, restart Rx and Tx
- Works for radios with opentx 2.2 or higher

<p align="center"><img src="./images/chgId.png" width="300"></p>
