# XenBlocks Stuff

-----

##  Miner based on Ubuntu Server with nvidia-settings support

### Features

1. Power limit
1. Fan speed
1. Max gpu clock limit
1. GPU and VRAM overclocking and undervolting support
1. Miner works as a system service with autostart
1. Miner is running in `tmux` terminal manager

### Prerequisities

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install x11-utils tmux
sudo apt install nvidia-driver-<version>
sudo reboot now
```

We need to create a `systemd` unit that will initialize X server and configure GPUs. It must be run by the `root` user.

```bash
sudo vi /etc/systemd/system/gpu_init.service
```

and paste the content of [gpu_init.service](https://github.com/DamianPala/XENBLOCKs-stuff/blob/main/gpu_init.service). 

Next create `gpu_init.sh`

```bash
vi ~/gpu_init.sh
```

and paste the content of [gpu_init.sh](https://github.com/DamianPala/XENBLOCKs-stuff/blob/main/gpu_init.sh). Set the configuration section according to your setup. The default configuration is intended to use with RTX 3090 graphic cards.
Using `max_gpu_clock`, `gpuClockOffsets` and `memoryOffsets` you can overclock your GPUs. Using those parameters with `power` parameter you can achieve undervolting by setting clocks higher and power limit lower.
`gpuClockOffsets` for most devices should be a multiply of 15 MHz. 
`max_gpu_clock` is really important parameter. It will limit the boost clock speed, which will increase stability of the overclocked core preventing clock speed spikes. It can also be used to limit the power of the card.

Set permissions:

```bash
chmod u+x ~/gpu_init.sh
```

In the `gpu_init.service` replace `<path>` with your `gpu_init.sh` file location.

Download and extract Xenblocks Miner (use latest version):

```bash
wget https://github.com/woodysoil/XenblocksMiner/releases/download/v1.3.1/xenblocksMiner-1.3.1-linux.tar.gz
tar -zxvf xenblocksMiner-1.3.1-linux.tar.gz
```

Finally create miner `systemd` unit

```bash
sudo vi /etc/systemd/system/xen_miner.service
```

and paste the content of [xen_miner.service](https://github.com/DamianPala/XENBLOCKs-stuff/blob/main/xen_miner.service).

Enable and start services:

```bash
sudo systemctl daemon-reload
sudo systemctl enable gpu_init.service
sudo systemctl enable xen_miner.service
sudo systemctl start gpu_init.service
sudo systemctl start xen_miner.service
```

Now your miner should start automatically with your configured GPUs every time you boot your system.
