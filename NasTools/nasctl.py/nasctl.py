#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys

CONFIG_FILE = os.path.expanduser("~/.nasctl.json")

def load_config():
    if not os.path.exists(CONFIG_FILE):
        print("Config file not found. Run 'nasctl configure' first.")
        sys.exit(1)
    with open(CONFIG_FILE) as f:
        return json.load(f)

def save_config(cfg):
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f, indent=2)
    os.chmod(CONFIG_FILE, 0o600)

def run_cmd(cmd):
    try:
        subprocess.check_call(cmd, shell=True)
    except subprocess.CalledProcessError as e:
        print(f"Command failed: {e}")
        sys.exit(1)

def configure(args):
    cfg = {
        "ip": args.ip,
        "share": args.share,
        "mountpoint": args.mountpoint,
        "username": args.username,
        "password": args.password,
        "vers": args.vers
    }
    save_config(cfg)
    print(f"Configuration saved to {CONFIG_FILE}")

def mount(args):
    cfg = load_config()
    os.makedirs(cfg["mountpoint"], exist_ok=True)
    cmd = (
        f'sudo mount -t cifs //{cfg["ip"]}/{cfg["share"]} {cfg["mountpoint"]} '
        f'-o username={cfg["username"]},password={cfg["password"]},vers={cfg["vers"]}'
    )
    run_cmd(cmd)
    print(f'Mounted {cfg["share"]} at {cfg["mountpoint"]}')

def umount(args):
    cfg = load_config()
    cmd = f"sudo umount {cfg['mountpoint']}"
    run_cmd(cmd)
    print(f"Unmounted {cfg['mountpoint']}")

def status(args):
    cfg = load_config()
    with open("/proc/mounts") as f:
        mounts = f.read()
    if cfg["mountpoint"] in mounts:
        print(f"✅ NAS is mounted at {cfg['mountpoint']}")
    else:
        print("❌ NAS is not mounted")

def main():
    parser = argparse.ArgumentParser(description="NAS mount manager")
    sub = parser.add_subparsers()

    pconf = sub.add_parser("configure", help="Configure NAS settings")
    pconf.add_argument("--ip", required=True, help="NAS IP address")
    pconf.add_argument("--share", required=True, help="Share name")
    pconf.add_argument("--mountpoint", required=True, help="Local mount point")
    pconf.add_argument("--username", required=True)
    pconf.add_argument("--password", required=True)
    pconf.add_argument("--vers", default="2.1", help="SMB version (default=2.1)")
    pconf.set_defaults(func=configure)

    pmount = sub.add_parser("mount", help="Mount NAS")
    pmount.set_defaults(func=mount)

    pumount = sub.add_parser("umount", help="Unmount NAS")
    pumount.set_defaults(func=umount)

    pstatus = sub.add_parser("status", help="Check NAS mount status")
    pstatus.set_defaults(func=status)

    args = parser.parse_args()
    if hasattr(args, "func"):
        args.func(args)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
