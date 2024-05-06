# HDMI-simulator
Simulation of a HDMI monitor to be used on a "headless" mini PC.

Under certain circumstances it is necessary to have access to a PC without keyboard and monitor.
This PC is than connected through "remote desktop" of VNC.

During start-up of the PC, the Operating System will not detect a monitor and assumes a default VGA-screen with a very low resolution.
After connecting with VNC is it impossible to change the resolution.

In my case the problem appears on a mini-PC with HDMI uitgang.  To overcome this problem I made a "HDMI fuzzer".
The device simulates an LG-television monitor with HDMI input.

During normal start-up of the PC the HDMI connection receives data from the monitor.  This data consists of blocks of 128 bytes.
The data communication follows the I2C protocol.  The Fuzzer has a "Arduino Pro Mini" that listens to this protocol and sends information containing the data for the LG monitor back to the PC.

The power for the Arduino (5 volt) is available on the HDMI cable.

The software for the Arduino does not use the "wire" library because"repeated start" was not supported.  Therefore 
we use an assember program without any library.

The sourcecode is available here.  The code is heavily commented to clarify the operation.

Later on it was found that a missing mouse had also issues when using VNC.  That was easily cured by using a USB nano mouse receiver in one of the free USB slots.

Below is a picture of the device. 

![image](https://github.com/Edzelf/HDMI-simulator/assets/18257026/abb9495b-c51a-4943-9093-cb7443618646)
