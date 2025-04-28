# Battery Monitor Script
This script was created to help benchmark a LiFePO₄ battery I purchased for my camper.

It monitors power consumption on Linux laptops, including support for (NVIDIA) GPU power monitoring.
The script tracks charging from an external source and automatically exits when charging stops (e.g., when the battery runs out).

The script works on Ubuntu 22

## Dependecies

Install the following packages

```
sudo apt-get update
sudo apt-get install upower lm-sensors
```

and you might want to probe the battery if it's not loaded correctly

```
sudo modprobe battery
```
