# Hostmap Demo

This repository contains all things needed to demonstrate how [hostmap](https://github.com/yesseri/hostmap) works.

With hostmap you can track which NixOS system image is currently active on each host, and for linking those running system images back to the Git commits that produced them. In addition, you can see an historical view of a server's NixOS system images.

This demo starts four servers.

* a `hostmap-server` VM running the hostmap Server and Scraper
* two NixOS hosts: `host1` and `host2`
* your computer acts as a ci server supplying the mapping between nix image and git commit to the hostmap server

The activation logger that keeps track of nix os system images runs on `hostmap-server`, `host1`, and `host2`. By going to `http://localhost:8080` you can see the current and historical state of the fleet.


## Prerequisites

You need:

* Linux on `x86_64`
* Nix with flakes enabled
* QEMU/KVM support
* Git
* SSH

## Usage

Start the demo fleet:

```bash
nix run .#fleet-up && nix run .#demo
```

The demo will:
1. start the VM fleet if it is not already running
2. send the current Git commit to store-path mappings to Hostmap
3. activate host1 and host2
4. create demo commits that change the host configurations
5. send the new mappings to Hostmap
6. activate the changed hosts

See the state of the servers here:

```text
http://localhost:8080
```


To activate a single system image you can use:

```bash
./switch.sh <server|host1|host2>
```

To create a new system image and make it show in the ui, edit `hosts/host2.nix`, commit the change, and then link the current commit.

```bash
git add hosts/host2.nix
git commit -m "Change host2 demo configuration"
nix run .#link-current-commit
./switch-host2.sh
```

Refresh the UI again. `host2` should now have changed, while `host1` should still be running the previous system image.

Stop the vms:

```bash
nix run .#fleet-down
```


## SSH Access

```bash
nix develop
ssh root@localhost -p 2221 $DEMO_SSH_OPTS # hostmap-server
ssh root@localhost -p 2222 $DEMO_SSH_OPTS # host1
ssh root@localhost -p 2223 $DEMO_SSH_OPTS # host2
```

## Notes

This is a local demo environment. Do not use these settings in production.
