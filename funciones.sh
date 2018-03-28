#!/bin/bash

#Funcion para comprobar el nombre de las interfaces si son ethX o enp0sX
function comprobarnombreinterfaz {
if [[ $(ip a | egrep '^.:' | cut -d ':' -f 2 | sed 's/ //g') == *eth* ]]; then
        echo "si"
else
	echo "no"
fi
}

#Funcion para la posibilidad de cambiar el nombre de la interfaz.
function cambiarnombre {
if [[ $(comprobarnombreinterfaz) == "no" ]]; then
	read -p "Desea cambiar el nombre de la interfaz por ethX? (y/n): " opcion
	if [ $opcion = "y" ]; then
		sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"/g' /etc/default/grub
		update-grub
		echo "Deseas reiniciar el sistema para aplicar los cambios? (y/n): "
		read reinicio
		if [ $reinicio = "y" ]; then
			reboot
		fi
	fi
fi
}

#Funcion con la que comprobamos que el paquete esta instalado.
function comprobarpaquetedhcp {
PAQ=$(dpkg --get-selections | grep -w isc-dhcp-server | grep -w install)
if [ "$PAQ" = "" ]; then
	echo "no"
else
	echo "si"
fi
}

#Funcion instalacion del paquete isc-dhcp-server
function intalacion {
if [[ $(comprobarpaquetedhcp) == "no" ]]; then
	read -p "Desea intalar el paquete isc-dhcp-server? (y/n): " op
	if [ $op == "y" ]; then
		apt-get install -y isc-dhcp-server >&/dev/null
	fi
fi
}

#Funcion que de momento no la llamo en el programa principal
function interfazservidor {
interfaces=$(ip a | egrep '^.:' | cut -d ':' -f 2 | sed 's/ //g' | grep '^e')
while [[ "$interfaces" != *$1* ]]
do
	read -p "Introduce una interfaz valida: " interfaz
	#Quiero guardar el nombre de la interfaz en el programa principal y de esta manera no funciona
done
	if [[ $(cat /etc/default/isc-dhcp-server | grep 'INTERFACES') == INTERFACESv4* ]]; then
		sed -i 's/INTERFACESv4=""/INTERFACESv4="'$1'"/g' /etc/default/isc-dhcp-server
	else
		sed -i 's/INTERFACES=""/INTERFACES="'$1'"/g' /etc/default/isc-dhcp-server
	fi
}


function comprobarip {
	local  ip=$1
	local  stat=1
	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        	OIFS=$IFS
        	IFS='.'
        	ip=($ip)
        	IFS=$OIFS
        	[[ ${ip[0]} -le 255 && ${ip[1]} -le 255  && ${ip[2]} -le 255 &&  ${ip[3]} -le 255 ]]
        	stat=$?
        	echo $stat
	fi
return $stat
}

function comprobarred {
	local  ip=$1
	local  stat=1
	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        	OIFS=$IFS
        	IFS='.'
        	ip=($ip)
        	IFS=$OIFS
        	[[ ${ip[0]} -le 192 && ${ip[1]} -le 168  && ${ip[2]} -le 255 &&  ${ip[3]} -eq 0 ]]
        	stat=$?
        	echo $stat
	fi
return $stat
}

function comprobarmac {
        local  mac=$1
        local  stat=1
        if [[ $mac =~ ^[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}$ ]]; then
                stat=$?
                echo $stat
        fi
return $stat
}

#Funcion que configura los parametros de la red.
function configuracion {
if [[ $(cat /etc/dhcp/dhcpd.conf | egrep '^subnet') = "" ]]; then
	read -p "Direccion de red: " red
	while [[ $(comprobarred $red) != 0 ]]
	do
		read -p "Introduce una direccion de red válida: " red
	done
	read -p "Macara de red: " mask
	while [[ $(comprobarip $mask) != 0 ]]
	do
		read -p "Introduce una mascara válida: " mask
	done
	read -p "Introduce el rango inicio: " inicio
	while [[ $(comprobarip $inicio) != 0 ]]
	do
		read -p "Introduce una direccion válida: " inicio
	done
	read -p "Introduce el rango fin: " fin
	while [[ $(comprobarip $fin) != 0 ]]
	do
		read -p "Introduce una direccion válida: " fin
	done
	read -p "Introduce la puerta de enlace: " route
	while [[ $(comprobarip $route) != 0 ]]
	do
		read -p "Introduce una direccion válida: " route
	done
	read -p "Introduce el DNS Primario: " dns1
	while [[ $(comprobarip $dns1) != 0 ]]
	do
		read -p "Introduce una direccion válida: " dns1
	done
	read -p "Introduce el DNS Secundario: " dns2
	while [[ $(comprobarip $dns2) != 0 ]]
	do
		read -p "Introduce una direccion válida: " dns2
	done
	if [ $mask = "255.255.255.0" ]; then
		ip a add "$route"/24 dev "$1"
		ip l set dev "$1" up
		echo -e "subnet $red netmask $mask {\n   range $inicio $fin;\n   option routers $route;\n   option domain-name-servers $dns1, $dns2;\n}" >> /etc/dhcp/dhcpd.conf
	elif [ $mask = "255.255.0.0" ]; then
		ip a add "$route"/16 dev "$1"
		ip l set dev "$1" up
		echo -e "subnet $red netmask $mask {\n   range $inicio $fin;\n   option routers $route;\n   option domain-name-servers $dns1, $dns2;\n}" >> /etc/dhcp/dhcpd.conf
	else
		echo "Revisa la configuración"
	fi
fi
}

#Funcion para realizar reservas de ip.
function reservas {
        if [ $1 = "y" ]; then
                read -p "Introduce el nombre del host: " host
                read -p "Introduce la mac del equipo: " mac
                while [[ $(comprobarmac $mac) != 0 ]]
                do
                        read -p "Introduce una mac válida: " mac
                done
                read -p "Introduce la ip que vas a reservar: " ip
                while [[ $(comprobarip $ip) != 0 ]]
                do
                        read -p "Introduce una ip válida: " ip
                done
                echo -e "host $host {\nhardware ethernet $mac;\nfixed-address $ip;\n }" >> /etc/dhcp/dhcpd.conf
        fi
}

