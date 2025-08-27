Here’s a concise `README.md` written in your style:

---

# nasctl

A small command-line tool to manage mounting a Synology NAS on Linux.

## Installation

```bash
chmod +x nasctl.py
mv nasctl.py ~/bin/nasctl   # or /usr/local/bin/nasctl
```

Make sure `~/bin` is in your PATH.

## Configuration

Run once to set up NAS connection details:

```bash
nasctl configure \
  --ip 192.168.1.246 \
  --share Multimediale \
  --mountpoint /mnt/nas \
  --username rage \
  --password 'Theo7568850*' \
  --vers 2.1
```

The configuration is stored in `~/.nasctl.json` with permissions restricted.

## Usage

```bash
nasctl mount     # mount the NAS
nasctl status    # check mount status
nasctl umount    # unmount the NAS
```

## Notes

* Requires `cifs-utils` installed
* Credentials are stored locally in a protected file
