#!/bin/bash

echo ""
echo "======================================="
echo "SCRIPT INSTALACION SERVIDOR DHCPv4"
echo "======================================="
echo ""

source f.sh

#Comprobacion de usuario
if [ $(whoami) != "root" ]; then
	echo "¡ATENCION! Debes ser ROOT para ejecutar este script."
	echo ""
else
	cambiarnombre
	intalacion
	dhcpd=$(ps awx | grep 'dhcpd' | grep -v grep | wc -l)
	if [ $dhcpd == 1 ]; then
		echo "El servicio DHCP está ACTIVO."
		echo""
		read -p "Desea realizar alguna reserva(y/n): " menu
		echo""
		echo "IP RESERVADAS"
		echo ""
		echo "HOST	IP"
		cat /etc/dhcp/dhcpd.conf | egrep '^fixed' | cut -d ' ' -f 2 | sed 's/.$//g' > ip.txt
		cat /etc/dhcp/dhcpd.conf | egrep '^host' | cut -d ' ' -f 2 > host.txt
		paste host.txt ip.txt
		echo""
		rm -r host.txt ip.txt
		reservas $menu
		systemctl restart isc-dhcp-server
	elif [[ $(comprobarpaquetedhcp) == "si" ]]; then
		echo "INTERFACES DE NUESTRO EQUIPO:"
		echo""
		ip a | egrep '^.:' | cut -d ':' -f 2 | sed 's/ //g' | grep '^e'
		echo""
		read -p "Introduce la interfaz por donde va a repartir IPs: " interfaz
		interfaces=$(ip a | egrep '^.:' | cut -d ':' -f 2 | sed 's/ //g' | grep '^e')
		while [[ "$interfaces" != *$interfaz* ]]
		do
        	read -p "Introduce una interfaz valida: " interfaz
		done
        	if [[ $(cat /etc/default/isc-dhcp-server | grep 'INTERFACES') == INTERFACESv4* ]]; then
                	sed -i 's/INTERFACESv4=""/INTERFACESv4="'$1'"/g' /etc/default/isc-dhcp-server
        	else
                	sed -i 's/INTERFACES=""/INTERFACES="'$1'"/g' /etc/default/isc-dhcp-server
        	fi
		configuracion $interfaz
		read -p "Desea realizar alguna reserva(y/n): " menu
		reservas $menu
		systemctl restart isc-dhcp-server
	fi
fi

