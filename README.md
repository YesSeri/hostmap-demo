# Hostmap Demo

This repository contains all things needed to demonstrate how [hostmap](https://github.com/yesseri/hostmap) works.

With hostmap you can track which NixOS system image is currently active on each host, and for linking those running system images back to the Git commits that produced them. In addition, you can see an historical view of a server's NixOS system images.

This demo starts four servers.

* a `hostmap-server` VM running the hostmap Server and Scraper
* two NixOS hosts: `host1` and `host2`
* an `external-ci` VM that simulates a CI server sending store-path-to-commit mappings to hostmap

The activation logger that keeps track of nix os system images runs on `hostmap-server`, `host1`, and `host2`.

The `external-ci` server is a bare Git repository with a `post-receive` hook. When you push a commit to it, the hook evaluates the NixOS system store paths for `host1` and `host2`, then sends the mappings to the hostmap Server API. The 

By going to `http://localhost:8080` you can see the current and historical state of the fleet.


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
nix run .#fleet-up
```

Open the hostmap website:

```text
http://localhost:8080
```

Add the demo CI server as a Git remote:

```bash
git remote add demo-ci ssh://ci@localhost:2224/var/lib/ci/hostmap-demo.git
```

Push the current commit to the demo CI server:

```bash
git push demo-ci HEAD:master
```

The password for the `ci` user is:

```text
password
```

Activate the demo hosts:

```bash
./switch.sh server
./switch.sh host1
./switch.sh host2
```

Go to website. You should now see a list of the current system image for each host.

To demonstrate a change, edit `hosts/host2.nix`, commit the change, push it to the demo CI server, and activate only `host2`:

```bash
git add hosts/host2.nix
git commit -m "Change host2 demo configuration"
git push demo-ci HEAD:master
./switch-host2.sh
```

Refresh the UI again. `host2` should now have changed, while `host1` should still be running the previous system image.

Stop the fleet:

```bash
nix run .#fleet-down
```

The VM state and logs are stored in:

```text
.fleet-state/
```

## SSH Access

```bash
ssh root@localhost -p 2221 -i test-key # hostmap-server
ssh root@localhost -p 2222 -i test-key # host1
ssh root@localhost -p 2223 -i test-key # host2
ssh root@localhost -p 2224 -i test-key # external-ci
```

The root password is:

```text
password
```

## Notes

This is a local demo environment. It uses fixed passwords, root SSH login, and a demo API key. Do not use these settings in production.
