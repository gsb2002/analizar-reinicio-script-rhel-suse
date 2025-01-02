#!/bin/bash
fechareinicio=$(last -1x reboot | awk '/system boot/ {print $7"T"$8}')
rutacrash=$(find /var/crash -name "dmesg.txt" -printf "%T@\t%p\n" | sort -nr | head -n 1 | cut -f2-)
grep_exclude=": start[a-z]|: stop[a-z]|kernel: .*: Power Button|watching system buttons|Start[a-z]* Crash recovery kernel|PAM|Basis System|BY2 Database|floppy|blk_update_request|audit|shutting down normally|BOOT_IMAGE"
grep_include="recover[a-z]*|shut[a-z ]*down|rsyslogd|error|panic|oom|out of memory|fail|fault|timeout|sealert|qemu-ga|crash|bad block"

echo "-------------------------------------------"
who -br
echo "-------------------------------------------"
echo -e '\n'
output=$(last -Fxn2 shutdown reboot)
if [[ "$output" =~ reboot.*shutdown ]]; then
    echo "Reiniciado manualmente o programado."
else
statussar=$(systemctl is-active sysstat)
if [ "$statussar" == "active" ]; then
	diasar=$(last -1x reboot | awk '/system boot/ {printf "%02d", $7}')
	rutasar=$(find /var/log/sa/sa$diasar)
	if [[ -n "$rutasar" ]]; then
        echo LOAD AVERAGE
        sar -q -f "$rutasar" | grep -B20 -i restart
		echo -e '\n'
        echo CPU
        sar -f "$rutasar" | grep -B20 -i restart
		echo -e '\n'
        echo MEMORIA
        sar -r -f "$rutasar" | grep -B20 -i restart
        echo -e "\n"
    fi
fi
salidamessages=$(grep -B1000 -w "$fechareinicio" /var/log/messages* | grep -vE "$grep_exclude" | grep -iE "$grep_include")
if [[ -n "$salidamessages" ]]; then
    echo -e "REGISTROS DEL /VAR/LOG/MESSAGES:\n$salidamessages\n"
fi
if grep -q '^Storage=persistent' /etc/systemd/journald.conf || [[ -d "/var/log/journal" ]]; then
	salidajournal=$(journalctl -b -1 -x | grep -vE "$grep_exclude" | grep -iE "$grep_include")
    if [[ -n "$salidajournal" ]]; then
	echo -e "REGISTROS DEL JOURNALCTL:\n$salidajournal\n"
    fi
fi
if [ -d "/var/log/cluster" ]; then
	salidacluster=$(grep -B1000 -rw "$fechareinicio" /var/log/cluster/* \
    | grep -riE 'corosync|pacemaker|stonith|quorum|failed|connection lost|reconnect|timeout|join|leave')
    if [[ -n "$salidacluster" ]]; then
		echo -e "REGISTROS DEL CLUSTER:\n$salidacluster\n"
	fi
fi
if grep -qE 'total_vm|Out of memory' /var/log/messages ; then
    echo -e "REGISTROS DEL CONSUMO DE MEMORIA:\n"
    grep -E 'invoked oom-killer|Out of memory:' /var/log/messages
    echo -e "\n"
    sed -n '/total_vm/,/Out of memory/{p;/Out of memory/q}' /var/log/messages | grep -vE 'total_vm|Out of memory' | nl > /tmp/oom.txt
    sed -n '/1/p' /tmp/oom.txt | sed 's/^.*\]//' | awk '{m[$8] += $4; SUM += $4} END { printf "%20s %10s KiB \n", "Total_used_memory", SUM*4; for (item in m) { printf "%20s %10s KiB \n", item, m[item]*4 } }' | sort -k 2 -r -n  | head -10
    echo -e "\n"
else
:
fi
if [ -f "$rutacrash" ]; then
	echo -e "REGISTROS DEL VMCORE:"
	cat "$rutacrash" | grep -vE "$grep_exclude" | grep -iE "$grep_include"
	echo -e "\n"
	if grep -qE 'total_vm|Out of memory' $rutacrash ; then
		echo -e "REGISTROS DEL CONSUMO DE MEMORIA EN EL VMCORE:"
		grep -E 'invoked oom-killer|Out of memory:' $rutacrash
		echo -e "\n"
		sed -n '/total_vm/,/Out of memory/{p;/Out of memory/q}' $rutacrash | grep -vE 'total_vm|Out of memory' | nl > /tmp/oom_vmcore.txt
		sed -n '/1/p' /tmp/oom_vmcore.txt | sed 's/^.*\]//' | awk '{m[$8] += $4; SUM += $4} END { printf "%20s %10s KiB \n", "Total_used_memory", SUM*4; for (item in m) { printf "%20s %10s KiB \n", item, m[item]*4 } }' | sort -k 2 -r -n  | head -10
    fi
else
    echo "No existen archivos crash"
    echo "Si no hay evidencias de que ha provocado el reinicio, entonces verificar los registros de iDrac/ILOm o del hypervisor(si es una MV), en el momento del reinicio."
fi
fi