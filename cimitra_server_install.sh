#!/bin/bash
###########################################
# cimitra_linux_server_install.sh         #
# Author: Tay Kratzer - tay@cimitra.com   #
# Version: 1.0                            #
# Modify date: 4/29/2020                  #
###########################################
# Cimitra Server Installation Script

declare -i ROOT_USER=`whoami | grep -c "root"`

declare NO_ADDRESS="0.0.0.0"
declare CIMITRA_SERVER_ADDRESS=""
declare -i UNINSTALL=0
declare -i SHOW_HELP=0
declare -i DEBUG=0
declare -i REMOVE_ALL_DATA=0
declare -i REMOVE_DATA=0
declare -i REMOVE_SETTINGS_FILES=0
declare -i REMOVE_API_COMPONENTS=0
declare -i SYSTEMD_INSTALL=0

while getopts "adsnrvhU" opt; do
  case ${opt} in
    U) UNINSTALL=1
	DEBUG=1
      ;;
    a) REMOVE_API_COMPONENTS=1
      ;;
    v) DEBUG=1
      ;;
    d) REMOVE_ALL_DATA=1
      ;;
    n) REMOVE_DATA=1
      ;;
    s) REMOVE_SETTINGS_FILES=1
	SYSTEMD_INSTALL=1
      ;;
    h) SHOW_HELP="1"
      ;;
  esac
done


if [ $SHOW_HELP -eq 1 ]
then
echo ""
echo "--- Script Help ---"
echo ""
echo "Install Docker, Docker Compose Utility, Cimitra Server, Cimitra Agent"
echo ""
echo "$0"
echo ""
echo "When installing the Cimitra Agent, install as a systemd service"
echo ""
echo "$0 -s"
echo ""
echo "Show Help"
echo ""
echo "$0 -h"
echo ""
echo "-------------------"
if [ $UNINSTALL -eq 1 ]
then
echo ""
echo -e "\033[0;93m\033[0;92m"
echo "[ Complete Uninstall + Verbose Mode ]"
echo ""
echo -e "\e[41m$0 -Udans\033[0;93m\033[0;92m"
# echo "$0 -Udans"
echo ""
echo "U = Run Uninstall"
echo ""
echo "d = Database and API Components"
echo ""
echo "a = API Components"
echo ""
echo "n = Remove Database Completely"
echo ""
echo "s = Settings Files"
echo "-------------------"
fi
exit 0
fi

declare CIMITRA_SERVER_PORT="443"
declare -i PROCEED_WITH_AGENT_INSTALL=0
declare CIMITRA_API_SESSION_TOKEN=""
declare -i RUN_AGENT_INSTALL=1
declare CIMITRA_SERVER_ADMIN_ACCOUNT="admin@cimitra.com"
declare CIMITRA_SERVER_ADMIN_PASSWORD="changeme"
declare CIMITRA_SERVER_PORT="443"

ip address show 2> /dev/null
declare -i IP_COMMAND_EXISTS=`echo $?`

if [ $IP_COMMAND_EXISTS -eq 0 ]
then
CIMITRA_SERVER_ADDRESS=`ip address show | grep .255 | grep -v 172. | grep -v 172. | head -1 | awk -F "inet" '{printf $2}' | awk '{printf $1}' | awk -F "/" '{printf $1}'`
else
CIMITRA_SERVER_ADDRESS=`ifconfig | grep .255 | grep -v 172. | grep -v 127.0.0.1 | head -1 | awk -F "inet" '{printf $2}' | awk '{printf $1}'`
fi
declare -i CIMITRA_SERVER_ADDRESS_LENGTH=`echo "${CIMITRA_SERVER_ADDRESS}" | wc -m`

if [ $CIMITRA_SERVER_ADDRESS_LENGTH -lt 5 ]
then
CIMITRA_SERVER_ADDRESS="127.0.0.1"
fi

# echo "CIMITRA_SERVER_ADDRESS_LENGTH = $CIMITRA_SERVER_ADDRESS_LENGTH"

declare CIMITRA_SERVER_ADDRESS_DESCRIPTION="${CIMITRA_SERVER_ADDRESS}"
declare -i POST_OFFICE_IN_SET="0"
declare -i CIMITRA_AGENT_IN_SET="0"
declare CIMITRA_PAIRED_AGENT_ID=""
declare TEMP_FILE_DIRECTORY="/var/tmp"
declare SERVER_HOSTNAME=`hostname`
declare CIMITRA_AGENT_IN_UPPER=`basename ${SERVER_HOSTNAME} | tr [a-z] [A-Z]`
declare -i DOCKER_DAEMON_LOADED=0

if [ $CIMITRA_SERVER_ADDRESS == $NO_ADDRESS ]
then
CIMITRA_SERVER_ADDRESS="localhost"
CIMITRA_SERVER_ADDRESS_DESCRIPTION="<this server>"
fi

if [ $DEBUG -eq 1 ]
then
echo "CIMITRA_SERVER_ADDRESS = $CIMITRA_SERVER_ADDRESS"
echo "CIMITRA_SERVER_ADDRESS_DESCRIPTION = $CIMITRA_SERVER_ADDRESS_DESCRIPTION"
fi

CIMITRA_SERVER_DIRECTORY="/var/opt/cimitra/server"

function CALL_ERROR_EXIT()
{
ERROR_MESSAGE="$1"
ERROR_MESSAGE="  ${ERROR_MESSAGE}  "
echo ""
if [ -t 0 ]
then
echo "$(tput setaf 1)ERROR:$(tput setab 7)${ERROR_MESSAGE}$(tput sgr 0)"
else
echo "ERROR:${ERROR_MESSAGE}"
fi
echo ""
exit 1
}

function CALL_ERROR()
{
ERROR_MESSAGE="$1"
ERROR_MESSAGE="  ${ERROR_MESSAGE}  "
echo ""
if [ -t 0 ]
then
echo "$(tput setaf 1)ERROR:$(tput setab 7)${ERROR_MESSAGE}$(tput sgr 0)"
else
echo "ERROR:${ERROR_MESSAGE}"
fi
echo ""
}

function CALL_INFO()
{
INFO_MESSAGE="$1"
INFO_MESSAGE="  ${INFO_MESSAGE}  "
echo ""
if [ -t 0 ]
then
echo "$(tput setaf 2)$(tput setab 4)INFO:$(tput setaf 4)$(tput setab 7)${INFO_MESSAGE}$(tput sgr 0)"
else
echo "INFO:${INFO_MESSAGE}"
fi
echo ""
}

function CALL_COMMAND()
{
INFO_MESSAGE="$1"
INFO_MESSAGE="  ${INFO_MESSAGE}  "
echo ""
if [ -t 0 ]
then
echo "$(tput setaf 2)$(tput setab 4)COMMAND:$(tput setaf 4)$(tput setab 7)${INFO_MESSAGE}$(tput sgr 0)"
else
echo "COMMAND:${INFO_MESSAGE}"
fi
echo ""
}


# Confirm or install Docker
function CONFIRM_OR_INSTALL_DOCKER()
{

if [ $DEBUG -eq 1 ]
then
echo "IN: $FUNCNAME"
fi

CALL_COMMAND "docker"
{
declare -i DOCKER_EXISTS=`docker ; echo $?`
} 1> /dev/null 2> /dev/null

if [ $DOCKER_EXISTS -eq 0 ]
then

CALL_INFO "Docker Installation Confirmed"

{
docker ps 
} 1> /dev/null 2> /dev/null

DOCKER_DAEMON_LOADED=`echo $?`


	if [ $DOCKER_DAEMON_LOADED -eq 0 ]
	then
	return 0
	fi

CALL_INFO "Starting Docker Daemon"

CALL_COMMAND "systemctl start docker"
systemctl start docker

CALL_COMMAND "systemctl enable docker"
systemctl enable docker


{
docker ps 1> /dev/null 2> /dev/null
} 1> /dev/null 2> /dev/null

DOCKER_DAEMON_LOADED=`echo $?`

	if [ $DOCKER_DAEMON_LOADED -ne 0 ]
	then
	docker ps 
	CALL_ERROR_EXIT "Cannot Start The Docker Daemon"
	fi

return 0
fi

CALL_INFO "Docker Installation Beginning"

declare -i INSTALL_COMMAND_SET=0
DOCKER_INSTALL_COMMAND_TWO=":"

{
apt --help 1> /dev/null 2> /dev/null
} 1> /dev/null 2> /dev/null

declare -i APT_GET_INSTALLED=`echo $?`

if [ $APT_GET_INSTALLED -eq 0 ]
then
CALL_COMMAND "sudo apt update"
sudo apt update
INSTALL_COMMAND_SET=1
DOCKER_INSTALL_COMMAND="sudo apt install docker --assume-yes"
DOCKER_INSTALL_COMMAND_TWO="sudo apt install docker.io --assume-yes"
fi

if [ $INSTALL_COMMAND_SET -eq 0 ]
then

{
zypper --help 1> /dev/null 2> /dev/null
} 1> /dev/null 2> /dev/null

declare -i ZYPPER_INSTALLED=`echo $?`

	if [ $ZYPPER_INSTALLED -eq 0 ]
	then
	DOCKER_INSTALL_COMMAND="sudo zypper -n install docker"
	INSTALL_COMMAND_SET=1
	fi

fi


if [ $INSTALL_COMMAND_SET -eq 0 ]
then

{
yum --help 1> /dev/null 2> /dev/null
} 1> /dev/null 2> /dev/null

declare -i YUM_INSTALLED=`echo $?`

	if [ $YUM_INSTALLED -eq 0 ]
	then
	DOCKER_INSTALL_COMMAND="sudo yum -y install docker"
	INSTALL_COMMAND_SET=1
	fi

fi


CALL_COMMAND "${DOCKER_INSTALL_COMMAND}"

${DOCKER_INSTALL_COMMAND}

CALL_COMMAND "${DOCKER_INSTALL_COMMAND_TWO}"

${DOCKER_INSTALL_COMMAND_TWO}

{
declare -i DOCKER_EXISTS=`docker ; echo $?`
} 1> /dev/null 2> /dev/null


if [ $DOCKER_EXISTS -ne 0 ]
then
CALL_ERROR "Docker Installation Failed"
CALL_ERROR "Try These Options"
CALL_ERROR "1. Run this script again...and...again a few times, see if the problem fixes itself"
CALL_ERROR "2. Install Docker yourself, and then run this script again"
CALL_ERROR_EXIT "Option #1. is easisest, and often works, perhaps wait a few minutes in between"
fi

CALL_INFO "Starting Docker Daemon"

CALL_COMMAND "systemctl start docker"
systemctl start docker

CALL_COMMAND "systemctl enable docker"
systemctl enable docker

{
docker ps 1> /dev/null 2> /dev/null
} 1> /dev/null 2> /dev/null


DOCKER_DAEMON_LOADED=`echo $?`

	if [ $DOCKER_DAEMON_LOADED -ne 0 ]
	then
	docker ps 
	CALL_ERROR_EXIT "Cannot Start The Docker Daemon"
	fi

}

# Confirm or install docker-compose
function CONFIRM_OR_INSTALL_DOCKER_COMPOSE()
{

CALL_COMMAND "docker-compose"
{
declare -i DOCKER_COMPOSE_EXISTS=`docker-compose ; echo $?`
} 1> /dev/null 2> /dev/null

if [ $DOCKER_COMPOSE_EXISTS -lt 2 ]
then
CALL_INFO "Docker Compose (docker-compose) Installation Confirmed"
return 0
fi
CALL_INFO "Docker Compose (docker-compose) Installation Beginning"

CALL_COMMAND "sudo curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
"
sudo curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

CALL_COMMAND "sudo chmod +x /usr/local/bin/docker-compose"

if [ $DEBUG -eq 1 ]
then
sudo chmod +x /usr/local/bin/docker-compose 
else
{
sudo chmod +x /usr/local/bin/docker-compose 
} 1> /dev/null 2> /dev/null
fi

CALL_COMMAND "sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose"

if [ $DEBUG -eq 1 ]
then
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
else
{
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
} 1> /dev/null 2> /dev/null
fi




{
declare -i DOCKER_COMPOSE_EXISTS=`docker-compose ; echo $?`
} 1> /dev/null 2> /dev/null

if [ $DOCKER_COMPOSE_EXISTS -gt 1 ]
then
CALL_ERROR_EXIT "Docker Compose Utility Installation Failed"
fi

}


# Make the server directory /var/opt/cimitra/server
# Download the Cimitra Server YAML File
# Determine if port 443 is in use

function DOWNLOAD_CIMITRA_YAML_FILE()
{

declare -i ALT_PORT_USED=0

if [ $DEBUG -eq 1 ]
then
echo "IN: $FUNCNAME"
fi

{
mkdir -p ${CIMITRA_SERVER_DIRECTORY}
} 1> /dev/null 2> /dev/null

declare -i CD_WORKED=1

if [ $DEBUG -eq 1 ]
then
cd ${CIMITRA_SERVER_DIRECTORY}
else
{
cd ${CIMITRA_SERVER_DIRECTORY}
} 1> /dev/null 2> /dev/null
fi


CD_WORKED=`echo $?`

if [ $CD_WORKED -ne 0 ]
then
CALL_ERROR_EXIT "Cannot Access Path: ${CIMITRA_SERVER_DIRECTORY}"
fi

LOCAL_YAML_FILE="docker-compose.yml"

declare -i LOCAL_YAML_FILE_EXISTS=`test -f ./${LOCAL_YAML_FILE} ; echo $?`

if [ $LOCAL_YAML_FILE_EXISTS -eq 0 ]
then
CALL_INFO "YAML File: ${CIMITRA_SERVER_DIRECTORY}/${LOCAL_YAML_FILE} - Already Exists"
return 0
fi

CALL_INFO "Downloading YAML File To: ${CIMITRA_SERVER_DIRECTORY}/${LOCAL_YAML_FILE}"

DOWNLOAD_FILE="curl -LJO https://raw.githubusercontent.com/cimitrasoftware/docker/master/docker-compose.yml -o ./${LOCAL_YAML_FILE}"

{
cat < /dev/tcp/localhost/443 &
} 2> /dev/null

CONNECTION_PROCESS=$!

declare -i CONNECTION_PROCESS_WORKED=`ps -eaf | grep ${CONNECTION_PROCESS} | grep -c "cat"`

if [ $CONNECTION_PROCESS_WORKED -gt 0 ]
then

{
cat < /dev/tcp/localhost/444 &
} 2> /dev/null

CONNECTION_PROCESS=$!

declare -i CONNECTION_PROCESS_WORKED=`ps -eaf | grep ${CONNECTION_PROCESS} | grep -c "cat"`

	if [ $CONNECTION_PROCESS_WORKED -eq 0 ]
	then
	ALT_PORT_USED=1
	DOWNLOAD_FILE="curl -LJO https://raw.githubusercontent.com/cimitrasoftware/docker/master/docker-compose-444.yml"
	CIMITRA_SERVER_PORT="444"
	fi


fi

CALL_COMMAND "${DOWNLOAD_FILE}"


${DOWNLOAD_FILE}

if [ $ALT_PORT_USED -eq 1 ]
then
mv -v ${CIMITRA_SERVER_DIRECTORY}/docker-compose-444.yml  ${CIMITRA_SERVER_DIRECTORY}/${LOCAL_YAML_FILE}
fi


}


# Bring up the Cimitra Server
function START_CIMITRA_DOCKER_CONTAINER()
{

if [ $DEBUG -eq 1 ]
then
echo "IN: $FUNCNAME"
fi

CALL_INFO "Initiating Cimitra Server Docker Containers"
echo ""
CALL_INFO "Installing Cimitra Server Components from Docker Hub"
CALL_COMMAND "cd ${CIMITRA_SERVER_DIRECTORY}"
cd ${CIMITRA_SERVER_DIRECTORY}
CALL_COMMAND "docker-compose up -d"
docker-compose up -d

DOCKER_UP_STATUS=`echo $?`

if [ $DOCKER_UP_STATUS -ne 0 ]
then
CALL_ERROR_EXIT "Cannot Start the Cimitra Server Docker Container"
fi

CALL_INFO "The Cimitra Server Was Successfully Installed"

CIMITRA_SERVER_PORT=`cat ${CIMITRA_SERVER_DIRECTORY}/${LOCAL_YAML_FILE} | grep ":443" | head -1 | awk -F : '{printf $1}' | awk -F "-" '{printf $2}' | sed 's/  *//g'`

case $CIMITRA_SERVER_PORT in
443)
CALL_INFO "Login to Cimitra @ https://${CIMITRA_SERVER_ADDRESS_DESCRIPTION}"
;;
*)
CALL_INFO "Log into Cimitra @ https://${CIMITRA_SERVER_ADDRESS_DESCRIPTION}:${CIMITRA_SERVER_PORT}"
;;
esac
}

function CONNECT_TEST()
{

if [ $DEBUG -eq 1 ]
then
echo "IN: $FUNCNAME"
fi

if [ $DEBUG -eq 1 ]
then
cat < /dev/tcp/${CIMITRA_SERVER_ADDRESS}/${CIMITRA_SERVER_PORT} &
else
{
cat < /dev/tcp/${CIMITRA_SERVER_ADDRESS}/${CIMITRA_SERVER_PORT} &
} 2> /dev/null
fi

CONNECTION_PROCESS=$!

declare -i CONNECTION_PROCESS_WORKED=`ps -eaf | grep ${CONNECTION_PROCESS} | grep -c "cat"`

if [ $CONNECTION_PROCESS_WORKED -eq 0 ]
then
return 1
else
return 0
fi

}

function ESTABLISH_CIMITRA_API_SESSION()
{

if [ $DEBUG -eq 1 ]
then
echo "IN: $FUNCNAME"
fi

# CALL_INFO "Establishing Connection to Cimitra Server"

BASEURL="https://${CIMITRA_SERVER_ADDRESS}:${CIMITRA_SERVER_PORT}/api" 

ENDPOINT="/users/login" 

URL="${BASEURL}${ENDPOINT}" 

DATA="{\"email\":\"${CIMITRA_SERVER_ADMIN_ACCOUNT}\",\"password\": \"${CIMITRA_SERVER_ADMIN_PASSWORD}\"}" 


if [ $DEBUG -eq 1 ]
then
RESPONSE=`curl -k -f -H "Content-Type:application/json" -X POST ${URL} --data "$DATA"`
else
{
RESPONSE=`curl -k -f -H "Content-Type:application/json" -X POST ${URL} --data "$DATA"`
} 2> /dev/null
fi



declare -i STATUS=`echo "${RESPONSE}" | grep -c ',\"homeFolderId\":\"'` 

if [ $DEBUG -eq 1 ]
then

	if [ ${STATUS} -eq 0 ] 
	then
	echo "Cannot Get a Valid Connection to the Cimitra Server"
	else
	echo "Got a Valid Connection to the Cimitra Server"
	fi

fi

if [ ${STATUS} -eq 0 ] 
then
PROCEED_WITH_AGENT_INSTALL="1"
return 1
fi 

CIMITRA_API_SESSION_TOKEN=`echo "${RESPONSE}" | awk -F \"token\":\" '{printf $2}' | awk -F \" '{printf $1}'`

# CALL_INFO "Established API Connection to Cimitra Server"
}

function CREATE_PAIRED_CIMITRA_AGENT()
{

if [ $DEBUG -eq 1 ]
then
echo "IN: $FUNCNAME"
fi

if [ $DEBUG -eq 1 ]
then

	if [ $PROCEED_WITH_AGENT_INSTALL -ne 0 ]
	then
	echo "Agent Install Process Not Proceeding"
	else
	echo "Agent Install Process Proceeding"
	fi

fi

if [ $PROCEED_WITH_AGENT_INSTALL -ne 0 ]
then
return 1
fi

AGENT_NAME="${CIMITRA_AGENT_IN_UPPER}"

BASEURL="https://${CIMITRA_SERVER_ADDRESS}:${CIMITRA_SERVER_PORT}/api"
 
ENDPOINT="/agent" 

URL="${BASEURL}${ENDPOINT}" 

CALL_INFO "Creating a new Cimitra Agent by the name of: ${AGENT_NAME}"

JSON_TEMP_FILE_ONE="${TEMP_FILE_DIRECTORY}/$$.1.tmp.json"

THE_DESCRIPTION="Cimitra Agent Deployed to Server: ${AGENT_NAME}\nIf you need to install the agent again folllow these 4 Simple Steps\n1. Download the Cimitra Agent and put it on the server: ${AGENT_NAME} \n2. Make the cimagent file executable: chmod +x ./cimagent\n3. Install the Cimitra Agent with the command: ./cimagent c\n4. Start the Cimitra Agent with the command: cimitra start"

echo "{
    \"name\": \"${AGENT_NAME}\",
    \"description\": \"${THE_DESCRIPTION}\",
    \"platform\": \"linux\",
    \"match_regex\":  \"node01\"
}" 1> ${JSON_TEMP_FILE_ONE} 

if [ $DEBUG -eq 1 ]
then
declare RESPONSE=`curl -k ${CURL_OUTPUT_MODE} -H 'Accept: application/json' \
-H "Authorization: Bearer ${CIMITRA_API_SESSION_TOKEN}" \
-X POST ${URL} -d @${JSON_TEMP_FILE_ONE}  \
-H "Content-Type: application/json"`
else
{
declare RESPONSE=`curl -k ${CURL_OUTPUT_MODE} -H 'Accept: application/json' \
-H "Authorization: Bearer ${CIMITRA_API_SESSION_TOKEN}" \
-X POST ${URL} -d @${JSON_TEMP_FILE_ONE}  \
-H "Content-Type: application/json"`
} 1> /dev/null 2> /dev/null
fi

rm ${TEMP_FILE_DIRECTORY}/$$.tmp.agent.json 2> /dev/null

TEMP_FILE_ONE="${TEMP_FILE_DIRECTORY}/$$.1.tmp"

TEMP_FILE_TWO="${TEMP_FILE_DIRECTORY}/$$.2.tmp"

echo "$RESPONSE" 1> ${TEMP_FILE_ONE}

sed -e 's/[}"]*\(.\)[{"]*/\1/g;y/,/\n/' < ${TEMP_FILE_ONE} > ${TEMP_FILE_TWO}

declare -i ERROR_STATE=`cat ${TEMP_FILE_TWO} | grep -c "error"`

if [ $DEBUG -eq 1 ]
then

	if [ $ERROR_STATE -gt 0 ]
	then
	echo "Error State"
	cat ${TEMP_FILE_TWO}
	fi

fi

if [ $ERROR_STATE -gt 0 ]
then
rm ${TEMP_FILE_ONE} 2> /dev/null
rm ${TEMP_FILE_TWO} 2> /dev/null
return 1
fi

CALL_INFO "Created a new Cimitra Agent by the name of: ${AGENT_NAME}"


CIMITRA_PAIRED_AGENT_ID=`cat ${TEMP_FILE_TWO} | grep "_id:" | awk -F : '{printf $2}'`

if [ $DEBUG -eq 1 ]
then
echo "CIMITRA_PAIRED_AGENT_ID = $CIMITRA_PAIRED_AGENT_ID"
fi


rm ${TEMP_FILE_ONE} 2> /dev/null

rm ${TEMP_FILE_TWO} 2> /dev/null

}



function DOWNLOAD_AND_INSTALL_CIMITRA_AGENT()
{
if [ $SYSTEMD_INSTALL -eq 0 ]
then

cd ${TEMP_FILE_DIRECTORY}

curl -LJO https://raw.githubusercontent.com/cimitrasoftware/agent/master/cimitra_agent_install.sh -o ./ ; chmod +x ./cimitra_agent_install.sh ; ./cimitra_agent_install.sh ${CIMITRA_SERVER_ADDRESS} ${CIMITRA_SERVER_PORT} ${CIMITRA_SERVER_ADMIN_ACCOUNT} ${CIMITRA_SERVER_ADMIN_PASSWORD}


else

cd ${TEMP_FILE_DIRECTORY}

curl -LJO https://raw.githubusercontent.com/cimitrasoftware/agent/master/cimitra_agent_install.sh -o ./ ; chmod +x ./cimitra_agent_install.sh ; ./cimitra_agent_install.sh ${CIMITRA_SERVER_ADDRESS} ${CIMITRA_SERVER_PORT} ${CIMITRA_SERVER_ADMIN_ACCOUNT} ${CIMITRA_SERVER_ADMIN_PASSWORD} systemd

fi

}

function LOOK_FOR_GROUPWISE()
{

{
rcgrpwise 1> /dev/null 2> /dev/null
} 1> /dev/null 2> /dev/null

declare -i GRPWISE_EXISTS=`echo $?`

if [ $GRPWISE_EXISTS -lt 3 ]
then


sudo cimitra get gw 

cd /tmp
{
curl -LJO https://raw.githubusercontent.com/cimitrasoftware/groupwise/master/install -o ./ 1> /dev/null 2> /dev/null 
} 1> /dev/null 2> /dev/null

chmod +x ./install 

./install


fi
}

function DOWNLOAD_CIMITRA_APIS()
{

{
rcgrpwise 1> /dev/null 2> /dev/null
} 1> /dev/null 2> /dev/null

declare -i GRPWISE_EXISTS=`echo $?`

if [ $GRPWISE_EXISTS -lt 3 ]
then
{
sudo cimitra get gw & 1> /dev/null 2> /dev/null &
} 1> /dev/null 2> /dev/null 

fi

sudo cimitra get server 

sudo cimitra get import 

}


function main()
{

CALL_INFO "[ Cimitra Server Install Script - Start ]"

CALL_INFO "Confirming Local Server Address"

CALL_COMMAND "ping -c 2 ${CIMITRA_SERVER_ADDRESS}"

ping -c 2 ${CIMITRA_SERVER_ADDRESS} 1> /dev/null 2> /dev/null

declare -i CIMITRA_SERVER_ADDRESS_ACCESIBLE=`echo $?`

if [ $CIMITRA_SERVER_ADDRESS_ACCESIBLE -ne 0 ]
then
CIMITRA_SERVER_ADDRESS="127.0.0.1"
fi

CALL_INFO "1/5: Confirm/Install Docker"
CONFIRM_OR_INSTALL_DOCKER
CALL_INFO "2/5: Confirm/Install Docker Compose Utility"
CONFIRM_OR_INSTALL_DOCKER_COMPOSE
CALL_INFO "3/5: Confirm/Install Cimitra Server YAML File"
DOWNLOAD_CIMITRA_YAML_FILE
CALL_INFO "4/5: Download and Start Cimitra Server"
START_CIMITRA_DOCKER_CONTAINER

CALL_INFO "Waiting 20 Seconds for The Cimitra Server to Load"
CALL_COMMAND "sleep 20"
sleep 20
CONNECT_TEST
PROCEED_WITH_AGENT_INSTALL=`echo $1`

if [ $PROCEED_WITH_AGENT_INSTALL -ne 0 ]
then
CALL_INFO "Waiting Another 10 Seconds"
CALL_COMMAND "sleep 10"
sleep 10
CONNECT_TEST
PROCEED_WITH_AGENT_INSTALL=`echo $1`

	if [ $PROCEED_WITH_AGENT_INSTALL -ne 0 ]
	then
	CALL_INFO "Waiting Another 10 Seconds One More Time"
	CALL_COMMAND "sleep 10"
	sleep 10
	CONNECT_TEST
	PROCEED_WITH_AGENT_INSTALL=`echo $1`
	fi

fi

CALL_INFO "5/5: Download/Install Cimitra Agent"

if [ $PROCEED_WITH_AGENT_INSTALL -eq 0 ]
then
DOWNLOAD_AND_INSTALL_CIMITRA_AGENT
fi

		if [ $ROOT_USER -eq 1 ]
		then
		CALL_COMMAND "cimitra stop"
		cimitra stop  
		else
		CALL_COMMAND "sudo cimitra stop"
		sudo cimitra stop
		fi

		

		if [ $ROOT_USER -eq 1 ]
		then
		CALL_COMMAND "cimitra start"
		cimitra start  
		else
		CALL_COMMAND "sudo cimitra start"
		sudo cimitra start
		fi

DOWNLOAD_CIMITRA_APIS

sudo /var/opt/cimitra/api/server/create ${CIMITRA_SERVER_ADDRESS} ${CIMITRA_SERVER_PORT} ${CIMITRA_SERVER_ADMIN_ACCOUNT} ${CIMITRA_SERVER_ADMIN_PASSWORD} function=CREATE_NEW_SERVER_APPS

		if [ $ROOT_USER -eq 1 ]
		then
		CALL_COMMAND "cimitra"
		cimitra 
		else
		CALL_COMMAND "sudo cimitra"
		sudo cimitra
		fi

CALL_INFO "[ Cimitra Server Install Script - Finish ]"


LOOK_FOR_GROUPWISE


}

function STOP_CIMITRA_DOCKER_CONTAINER()
{
CALL_INFO "Removing Cimitra Server Docker Container"

CALL_COMMAND "cd ${CIMITRA_SERVER_DIRECTORY}"

cd ${CIMITRA_SERVER_DIRECTORY}

CALL_COMMAND "docker-compose down"

docker-compose down

DOCKER_UP_STATUS=`echo $?`

if [ $DOCKER_UP_STATUS -ne 0 ]
then
CALL_ERROR "Cannot Remove the Cimitra Server Docker Container"
fi

CALL_INFO "The Cimitra Server Docker Container Was Successfully Removed"

}

function REMOVE_DOCKER()
{

DOCKER_UNINSTALL_COMMAND="sudo zypper -n rm docker"
CALL_COMMAND "${DOCKER_UNINSTALL_COMMAND}"
${DOCKER_UNINSTALL_COMMAND}

}
 
function REMOVE_CIMITRA_DOCKER_COMPONENTS()
{

declare -i CIMITRA_WEB_IMAGE_EXISTS=`docker images -a | grep "cimitra/web" | wc -m`

if [ $CIMITRA_WEB_IMAGE_EXISTS -gt 2 ]
then
CIMITRA_WEB_IMAGE=`docker images -a | grep "cimitra/web" | awk '{printf $3}'`
CALL_INFO "Removing Cimitra Web Client Docker Image"
CALL_COMMAND "docker rmi ${CIMITRA_WEB_IMAGE}"
docker rmi ${CIMITRA_WEB_IMAGE}
fi

declare -i CIMITRA_SERVER_IMAGE_EXISTS=`docker images -a | grep "cimitra/server" | wc -m`

if [ $CIMITRA_SERVER_IMAGE_EXISTS -gt 2 ]
then
CIMITRA_SERVER_IMAGE=`docker images -a | grep "cimitra/server" | awk '{printf $3}'`
CALL_INFO "Removing Cimitra Server Docker Image"
CALL_COMMAND "docker rmi ${CIMITRA_SERVER_IMAGE}"
docker rmi ${CIMITRA_SERVER_IMAGE}
fi

}


function REMOVE_ALL_COMPONENTS()
{

CALL_COMMAND "cimitra stop"

{
cimitra stop & 1> /dev/null 2> /dev/null &
} 1> /dev/null 2> /dev/null 

STOP_CIMITRA_DOCKER_CONTAINER

REMOVE_CIMITRA_DOCKER_COMPONENTS

REMOVE_DOCKER

CALL_INFO "Successfully Uninstalled Cimitra and Supporting Components"
}

function REMOVE_MONGO_DB_DATA()
{
MONGO_DB_DIR="/var/lib/docker/volumes/server_mongodata"

declare -i CD_WORKED=1
cd ${MONGO_DB_DIR}
CD_WORKED=`echo $?`

if [ $CD_WORKED -ne 0 ]
then
return 1
fi

declare -i CURRENT_PATH=`pwd | grep -c ${MONGO_DB_DIR}`

if [ $CURRENT_PATH -ne 1 ]
then
return 1
fi

mv ./_data ./_data.$$

if [ $REMOVE_DATA -eq 1 ]
then
	if [ $DEBUG -eq 1 ]
	then
	rm -rv ./_data.$$
	else
	rm -r ./_data.$$
	fi
mkdir ./_data
fi
}

function REMOVE_CIMITRA_API_COMPONENTS()
{
CIMITRA_API_DIR="/var/opt/cimitra/api"

declare -i CD_WORKED=1
cd ${CIMITRA_API_DIR}
CD_WORKED=`echo $?`

if [ $CD_WORKED -ne 0 ]
then
return 1
fi

declare -i CURRENT_PATH=`pwd | grep -c ${CIMITRA_API_DIR}`

if [ $CURRENT_PATH -ne 1 ]
then
return 1
fi

rm -rv ./gw
rm -rv ./import
rm -rv ./server
}

function REMOVE_CIMITRA_AGENT()
{
CIMITRA_AGENT_BIN_FILE="/usr/bin/cimagent"
CIMITRA_AGENT_SYM_FILE="/usr/bin/cimitra"
CIMITRA_AGENT_SCRIPT_FILE="/etc/init.d/cimitra"

rm -v ${CIMITRA_AGENT_BIN_FILE}
rm -v ${CIMITRA_AGENT_SYM_FILE}
rm -v ${CIMITRA_AGENT_SCRIPT_FILE}
}

function REMOVE_SETTINGS_FILES()
{
GW_SETTINGS_FILE="/var/opt/cimitra/scripts/groupwise-master/helpdesk/settings_gw.cfg"
rm -v ${GW_SETTINGS_FILE}

API_SETTINGS_FILE="/var/opt/cimitra/api/settings_api.cfg"
rm -v ${API_SETTINGS_FILE}

YAML_FILE="/var/opt/cimitra/server/docker-compose.yml"
rm -v ${YAML_FILE}
}

if [ $UNINSTALL -eq 0 ]
then
main
else
REMOVE_ALL_COMPONENTS

	if [ $REMOVE_ALL_DATA -eq 1 ]
	then
	REMOVE_MONGO_DB_DATA
	REMOVE_CIMITRA_API_COMPONENTS
	REMOVE_CIMITRA_AGENT
	else
	
		if [ $REMOVE_API_COMPONENTS -eq 1 ]
		then
		REMOVE_CIMITRA_API_COMPONENTS
		fi
	fi


	if [ $REMOVE_SETTINGS_FILES -eq 1 ]
	then
	REMOVE_SETTINGS_FILES
	fi

fi


