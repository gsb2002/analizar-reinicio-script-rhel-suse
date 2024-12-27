#!/bin/bash
echo "-------------------------------------------"
who -br
echo "-------------------------------------------"
echo -e '\n'
output=$(last -Fxn2 shutdown reboot)
if [[ "$output" =~ reboot.*shutdown ]]; then
echo "Reiniciado manualmente o programado"
if grep -q "signal 15" /var/log/messages; then
echo -e '\n'
echo "El mensaje 'exiting on signal 15' indica un apagado normal."
grep -w "signal 15" /var/log/messages
fi
echo -e '\n'
history | grep -iE 'reboo|shutd'
else
status=$(systemctl is-active --quiet sysstat)
if [ "$status" == "active" ]; then
diasar=$(last -1x reboot | grep "system boot" | awk '{printf "%02d", $7}')
rutasar=$(find /var/log/sa/ -name "sa$diasar")
if [[ -n "$rutasar" ]]; then
echo LOAD AVERAGE
sar -q -f "$rutasar" | grep -i -B 10 restart
echo CPU
sar -f "$rutasar" | grep -i -B 10 restart
echo MEMORIA
sar -r -f "$rutasar" | grep -i -B 10 restart
echo -e "\n"
else
echo "No se encontró el archivo SAR para el día del reinicio."
fi
fi
dfin2=$(last -1x reboot | grep "system boot" |  awk  '{print $7,$8}')
salidamessages=$(grep -B1000 -w "$dfin2" /var/log/messages* \
 | grep -ivE ': start[a-z]|: stop[a-z]|kernel: .*: Power Button|watching system buttons|Started Crash recovery kernel|PAM|Basis System|BY2 Database|floppy|blk_update_request|audit|shutting down normally|BOOT_IMAGE=/vmlinuz' \
 | grep -iE 'recover[a-z]*|shut[a-z ]*down|rsyslogd|ups|error|panic|oom|fail|timeout|sealert|qemu-ga|crash')
if [[ "$salidamessages" != "" ]]; then
    echo -e "REGISTROS DEL /VAR/LOG/MESSAGES:\n"
    echo "$salidamessages"
fi
echo -e "\n"
if grep -q '^Storage=persistent' /etc/systemd/journald.conf || [[ -d "/var/log/journal" ]]; then
echo -e "REGISTROS DEL JOURNALCTL:\n"
salida1=$(journalctl -b -1 -p emerg..err -x)
if [[ "$salida1" != "-- No entries --" ]]; then
    echo "Salida journalctl -p emerg..err :"
    echo "$salida1"
    echo -e "\n"
fi
salida2=$(journalctl -b -1 -x \
 | grep -ivE ': start[a-z]|: stop[a-z]|kernel: .*: Power Button|watching system buttons|Started Crash recovery kernel|PAM|Basis System|BY2 Database|floppy|blk_update_request|audit|shutting down normally|BOOT_IMAGE=/vmlinuz' \
 | grep -iE 'recover[a-z]*|shut[a-z ]*down|rsyslogd|ups|error|panic|oom|fail|timeout|sealert|qemu-ga')
if [[ "$salida2" != "" ]]; then
    echo -e "REGISTROS DEL JOURNALCTL CON GREP:\n"
    echo "$salida2"
fi
echo -e "\n"
fi
if [[ -d "/var/log/audit" ]]; then
    result=$(aureport -u --failed -if /var/log/audit/audit.log -te boot | tail -n1000)
    if [[ "$result" != "<no matches>" ]]; then
        echo -e "REGISTROS DEL AUDIT:\n"
        echo "$result"
        echo -e "\n"
    fi
fi
if [ -d "/var/log/cluster" ]; then
echo -e "REGISTROS DEL CLUSTER:\n"
grep -B1000 -rw "$dfin2" /var/log/cluster/* \
| grep -riE 'corosync|pacemaker|stonith|quorum|failed|connection lost|reconnect|timeout|join|leave'
echo -e "\n"
fi
if grep -qE 'total_vm|Out of memory' /var/log/messages ; then
echo -e "REGISTROS DEL CONSUMO DE MEMORIA:\n"
grep -E 'invoked oom-killer|Out of memory:' /var/log/messages
echo -e "\n"
sed -n '/total_vm/,/Out of memory/{p;/Out of memory/q}' /var/log/messages | grep -vE 'total_vm|Out of memory' | nl > /tmp/oom.txt
sed -n '/1/p' /tmp/oom.txt | sed 's/^.*\]//' | awk '{m[$8] += $4; SUM += $4} END { printf "%20s %10s KiB \n", "Total_used_memory", SUM*4; for (item in m) { printf "%20s %10s KiB \n", item, m[item]*4 } }' | sort -k 2 -r -n  | head -10
echo -e "\n"
fi
if [ -d "/var/crash" ]; then
    num_files=$(find /var/crash -type f | wc -l)
    if [ "$num_files" -gt 0 ]; then
        echo -e "Existe el archivo vmcore en /var/crash :"
		ls -ltr /var/crash | grep -v total
		echo -e "\n"
        echo -e "Tienes 2 opciones para analizar:\n
	Primera opcion:
	A traves de la url https://access.redhat.com/labs/kerneloopsanalyzer/ y depositando el archivo vmcore-dmesg.txt\n
	Segunda opcion:
        Reúna el detalle del proceso que se estaban ejecutando en el momento del bloqueo a un archivo llamado bt.txt
        echo \"bt\" | crash /usr/***/vmlinux /var/crash/***/vmcore > bt.txt\n"
		else
        echo "No existe archivos crash"
	echo "Si no hay evidencias de que ha provocado el reinicio, entonces verificar los registros de iDrac/ILOm o del hypervisor(si es una MV), en el momento del reinicio."
fi
fi
fi