# Samba Workspace Setup

This guide shares only the OpenClaw workspace with authorized host users. It
does not share `data/`, `/home/clawvm`, or any directory containing OpenClaw
configuration, tokens, credentials, or user-local tools.

Run the Docker setup and install OpenClaw before applying these commands. The
workspace path is always:

```text
<clawvm checkout>/data/.openclaw/workspace
```

## 1. Create a collaboration group

Run these commands on the Linux host. Replace `alice` with each host user who
may access the shared workspace.

```bash
sudo groupadd --system clawvm-share
sudo usermod -aG clawvm-share alice
```

Each added user must log out and log in again before its new group membership is
active. Samba users must also have a local Unix account and a Samba password:

```bash
sudo smbpasswd -a alice
```

## 2. Apply workspace ownership and ACLs

Run from the ClawVM checkout. This assigns OpenClaw's fixed container UID `1000`
as the workspace owner and grants the dedicated host group access. The setgid
bit and default ACLs make future files created by OpenClaw or Samba available to
both sides without `777` permissions.

```bash
WORKSPACE="$(realpath data/.openclaw/workspace)"
sudo install -d -o 1000 -g clawvm-share -m 2770 "$WORKSPACE"
sudo setfacl -m u:1000:rwx,g:clawvm-share:rwx,m::rwx,o::--- "$WORKSPACE"
sudo setfacl -d -m u::rwx,u:1000:rwx,g::rwx,g:clawvm-share:rwx,m::rwx,o::--- "$WORKSPACE"
```

Confirm the result:

```bash
getfacl "$WORKSPACE"
stat --format='%A %u %g %n' "$WORKSPACE"
```

The output must show a setgid directory, owner UID `1000`, group
`clawvm-share`, and no permissions for `other`.

## 3. Add the Samba share

Back up `/etc/samba/smb.conf`, then append this share definition. Replace the
example path with the absolute value printed by `echo "$WORKSPACE"` above.

```ini
[clawvm-workspace]
    path = /absolute/path/to/clawvm/data/.openclaw/workspace
    browseable = yes
    read only = no
    guest ok = no
    valid users = @clawvm-share
    force group = +clawvm-share
    create mask = 0660
    force create mode = 0660
    directory mask = 2770
    force directory mode = 2770
    inherit acls = yes
    map acl inherit = yes
```

Validate and reload Samba:

```bash
sudo testparm
sudo systemctl reload smbd
```

The service name can be `samba` rather than `smbd` on some Linux distributions.

## 4. Verify both directions

Create a file as a Samba-authorized host user:

```bash
sudo -u alice sh -c 'printf "from host\n" > "'$WORKSPACE'/from-host.txt"'
docker compose exec clawvm bash -lc 'cat ~/.openclaw/workspace/from-host.txt'
```

Create a file as OpenClaw's container user and read it as the host user:

```bash
docker compose exec clawvm bash -lc 'printf "from OpenClaw\n" > ~/.openclaw/workspace/from-openclaw.txt'
sudo -u alice cat "$WORKSPACE/from-openclaw.txt"
```

Use a Samba client with `alice` to create and edit the same files through the
`clawvm-workspace` share. The files should be group-readable and group-writable,
not world-writable.

## Security checks

- Do not configure a Samba share for `data/` or `/home/clawvm`.
- Do not enable `guest ok`.
- Keep `valid users` restricted to `@clawvm-share`.
- Review group members with `getent group clawvm-share`.
- Back up with ACLs and extended attributes: `rsync -aAX --numeric-ids`.