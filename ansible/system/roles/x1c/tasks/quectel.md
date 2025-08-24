# Quectel 5G modem

- Quectel RM520N-GL 5G M.2 WWAN

## debug

08:00.0 Unassigned class [ff00]: Quectel Wireless Solutions Co., Ltd. Device [1eac:1007]

- https://wiki.archlinux.org/title/Mobile_broadband_modem#FCC_locking

this fixed the issue for me:

```bash
ln -s /usr/share/ModemManager/fcc-unlock.available.d/1eac\:1007 /etc/ModemManager/fcc-unlock.d/1eac:1007
systemctl restart ModemManager
```
