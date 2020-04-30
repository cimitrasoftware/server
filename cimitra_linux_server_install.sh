#!/bin/bash
###########################################
# cimitra_server_install.sh               #
# Author: Tay Kratzer - tay@cimitra.com   #
# Version: 1.0                            #
# Modify date: 4/29/2020                  #
###########################################
# Cimitra Server Installation Script

declare -i ROOT_USER=`whoami | grep -c "root"`

declare NO_ADDRESS="0.0.0.0"
declare -i UNINSTALL=0
declare -i SHOW_HELP=0
declare -i DEBUG=0
declare -i REMOVE_ALL_DATA=0
declare -i NUKE_DATA=0
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
    n) NUKE_DATA=1
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
echo "n = Remove Database Completely (nuke)"
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
declare CIMITRA_SERVER_ADDRESS=`ip address show eth0 | grep inet | head -1 | awk '{printf $2}' | awk -F "/" '{printf $1}'`
declare -i CIMITRA_SERVER_ADDRESS_LENGTH=`echo "${CIMITRA_SERVER_ADDRESS}" | wc -m`
if [ $CIMITRA_SERVER_ADDRESS_LENGTH -lt 5 ]
then
CIMITRA_SERVER_ADDRESS="127.0.0.1"
fi

echo "CIMITRA_SERVER_ADDRESS_LENGTH = $CIMITRA_SERVER_ADDRESS_LENGTH"

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
CALL_ERROR_EXIT "Docker Installation Failed"
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

declare -i CONNECTION_PROCESS_WORKED=`ps -aux | grep ${CONNECTION_PROCESS} | grep -c "cat"`

if [ $CONNECTION_PROCESS_WORKED -gt 0 ]
then

{
cat < /dev/tcp/localhost/444 &
} 2> /dev/null

CONNECTION_PROCESS=$!

declare -i CONNECTION_PROCESS_WORKED=`ps -aux | grep ${CONNECTION_PROCESS} | grep -c "cat"`

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

declare -i CONNECTION_PROCESS_WORKED=`ps -aux | grep ${CONNECTION_PROCESS} | grep -c "cat"`

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

THE_DESCRIPTION="Cimitra Agent Deployed to Server: ${AGENT_NAME}\nIf you need to install the agent again folllow these 4 Simple Steps\n1. Download the Cimitra Agent and put it on the Linux server: ${AGENT_NAME} \n2. Make the cimagent file executable: chmod +x ./cimagent\n3. Install the Cimitra Agent with the command: ./cimagent c\n4. Start the Cimitra Agent with the command: cimitra start"

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



if [ $DEBUG -eq 1 ]
then
echo "IN: $FUNCNAME"
fi

if [ $PROCEED_WITH_AGENT_INSTALL -ne 0 ]
then
return
fi

CIMITRA_AGENT_BINARY_FILE="/usr/bin/cimagent"

declare -i CIMITRA_AGENT_INSTALLED=`test -f ${CIMITRA_AGENT_BINARY_FILE} ; echo $?`

# If an agent isn't installed....
if [ $CIMITRA_AGENT_INSTALLED -eq 1 ]
then

BASEURL="https://${CIMITRA_SERVER_ADDRESS}:${CIMITRA_SERVER_PORT}/api"
 
ENDPOINT="/agent" 

URL="${BASEURL}${ENDPOINT}" 

# Look for all agents

if [ $DEBUG -eq 1 ]
then

declare RESPONSE=`curl -k ${CURL_OUTPUT_MODE} -H 'Accept: application/json' \
-H "Authorization: Bearer ${CIMITRA_API_SESSION_TOKEN}" \
-X GET ${URL}`

else

{
declare RESPONSE=`curl -k ${CURL_OUTPUT_MODE} -H 'Accept: application/json' \
-H "Authorization: Bearer ${CIMITRA_API_SESSION_TOKEN}" \
-X GET ${URL}`
} 1> /dev/null 2> /dev/null

fi



TEMP_FILE_ONE="${TEMP_FILE_DIRECTORY}/$$.1.tmp"

TEMP_FILE_TWO="${TEMP_FILE_DIRECTORY}/$$.2.tmp"

echo "$RESPONSE" 1> ${TEMP_FILE_ONE}

sed -e 's/[}"]*\(.\)[{"]*/\1/g;y/,/\n/' < ${TEMP_FILE_ONE} > ${TEMP_FILE_TWO}

CIMITRA_AGENT_IN_SET=1

SERVER_HOSTNAME=`hostname`





	
	declare -i CIMITRA_AGENT_NAME_EXISTS=`cat ${TEMP_FILE_TWO} | grep -icw "name:${AGENT_NAME}"`

if [ $DEBUG -eq 1 ]
then
echo "CIMITRA_AGENT_NAME_EXISTS = $CIMITRA_AGENT_NAME_EXISTS"
fi


	if [ $CIMITRA_AGENT_NAME_EXISTS -gt 0 ]
	then
	CIMITRA_PAIRED_AGENT_ID=`cat ${TEMP_FILE_TWO} | grep -iwB 1 "name:${AGENT_NAME}" | head -1 | awk -F ":" '{printf $2}'`

		if [ $DEBUG -eq 1 ]
		then
		echo "CIMITRA_PAIRED_AGENT_ID = $CIMITRA_PAIRED_AGENT_ID"
		fi
	else

		if [ $DEBUG -eq 1 ]
		then
		echo "Calling Function CREATE_PAIRED_CIMITRA_AGENT"
		fi

	CREATE_PAIRED_CIMITRA_AGENT
	fi		



fi

if [ $CIMITRA_AGENT_INSTALLED -eq 0 ]
then
# echo "AGENT IS INSTALLED...Let's keep checking"
# Determine if the installed Cimitra Agent is actually still registered in Cimitra


CIMITRA_AGENT_IN_SET=1
SERVER_HOSTNAME=`hostname`


CIMITRA_BINARY_AGENT_ID=`sudo ${CIMITRA_AGENT_BINARY_FILE} | grep -iA1 "agentid" | tail -1 | awk -F "= " '{printf $2}'`

if [ $DEBUG -eq 1 ]
then
echo "CIMITRA_BINARY_AGENT_ID = $CIMITRA_BINARY_AGENT_ID"
fi


BASEURL="https://${CIMITRA_SERVER_ADDRESS}:${CIMITRA_SERVER_PORT}/api"
 
ENDPOINT="/agent" 

URL="${BASEURL}${ENDPOINT}" 

if [ $DEBUG -eq 1 ]
then

declare RESPONSE=`curl -k ${CURL_OUTPUT_MODE} -H 'Accept: application/json' \
-H "Authorization: Bearer ${CIMITRA_API_SESSION_TOKEN}" \
-X GET ${URL}`

else

{
declare RESPONSE=`curl -k ${CURL_OUTPUT_MODE} -H 'Accept: application/json' \
-H "Authorization: Bearer ${CIMITRA_API_SESSION_TOKEN}" \
-X GET ${URL}`
} 1> /dev/null 2> /dev/null

fi

TEMP_FILE_ONE="${TEMP_FILE_DIRECTORY}/$$.1.tmp"

TEMP_FILE_TWO="${TEMP_FILE_DIRECTORY}/$$.2.tmp"

echo "$RESPONSE" 1> ${TEMP_FILE_ONE}

sed -e 's/[}"]*\(.\)[{"]*/\1/g;y/,/\n/' < ${TEMP_FILE_ONE} > ${TEMP_FILE_TWO}

SEARCH_FOR="${CIMITRA_BINARY_AGENT_ID}"

declare -i CIMITRA_AGENT_ID_EXISTS=`cat ${TEMP_FILE_TWO} | grep -icw "_id:${SEARCH_FOR}"`


if [ $DEBUG -eq 1 ]
then
echo "CIMITRA_AGENT_ID_EXISTS = $CIMITRA_AGENT_ID_EXISTS"
fi

	if [ $CIMITRA_AGENT_ID_EXISTS -gt 0 ]
	then
	CIMITRA_PAIRED_AGENT_ID=`cat ${TEMP_FILE_TWO} | grep -iw  "_id:${SEARCH_FOR}" | head -1 | awk -F ":" '{printf $2}'`
	CIMITRA_PAIRED_AGENT_NAME=`cat ${TEMP_FILE_TWO} | grep -A 1 ${SEARCH_FOR} | tail -1 | awk -F ":" '{printf $2}'`
	CIMITRA_PAIRED_AGENT_NAME_LOWER=`echo "${CIMITRA_PAIRED_AGENT_NAME}" | tr [A-Z] [a-z]`
	

		if [ $DEBUG -eq 1 ]
		then
		echo "CIMITRA_PAIRED_AGENT_ID = $CIMITRA_PAIRED_AGENT_ID"
		echo "CIMITRA_PAIRED_AGENT_NAME = $CIMITRA_PAIRED_AGENT_NAME"
		fi

	rm ${TEMP_FILE_ONE} 2> /dev/null
	rm ${TEMP_FILE_TWO} 2> /dev/null
	return 0

		
	else



		AGENT_NAME="${CIMITRA_AGENT_IN_UPPER}"

		if [ $DEBUG -eq 1 ]
		then
		echo "AGENT_NAME = $AGENT_NAME"
		fi


	declare -i CIMITRA_AGENT_NAME_EXISTS=`cat ${TEMP_FILE_TWO} | grep -icw "name:${AGENT_NAME}"`


		if [ $CIMITRA_AGENT_NAME_EXISTS -gt 0 ]
		then
			CIMITRA_PAIRED_AGENT_ID=`cat ${TEMP_FILE_TWO} | grep -iwB 1 "name:${AGENT_NAME}" | head -1 | awk -F ":" '{printf $2}'`
		else
			echo ""
			echo "Process: Replacing the existing Cimitra Agent"
			echo ""
			rm ${TEMP_FILE_ONE} 2> /dev/null
			rm ${TEMP_FILE_TWO} 2> /dev/null
			CREATE_PAIRED_CIMITRA_AGENT
		fi		


	fi

fi

rm ${TEMP_FILE_ONE} 2> /dev/null

rm ${TEMP_FILE_TWO} 2> /dev/null

DATA="{\"host\": \"${CIMITRA_SERVER_ADDRESS}\",\"port\": \"${CIMITRA_SERVER_PORT}\",\"root\": \"/api\",\"arch\": \"x64\"}" 

BASEURL="https://${CIMITRA_SERVER_ADDRESS}:${CIMITRA_SERVER_PORT}/api"

ENDPOINT="/agent/${CIMITRA_PAIRED_AGENT_ID}/download"

URL="${BASEURL}${ENDPOINT}" 

CIMAGENT_FILE="${TEMP_FILE_DIRECTORY}/cimagent"

# echo "CIMITRA_PAIRED_AGENT_ID = $CIMITRA_PAIRED_AGENT_ID"

# echo "DATA = $DATA"

if [ $DEBUG -eq 1 ]
then
sudo rm ${CIMAGENT_FILE} 
else
	if [ $ROOT_USER -eq 1 ]
	then
	rm ${CIMAGENT_FILE} 2> /dev/null
	else
	sudo rm ${CIMAGENT_FILE}
	fi

fi



echo ""
echo "Process: Downloading the Cimitra Agent File (this may take a little bit...)"
echo ""
echo "-----------------------------------------------------------------------------"
echo ""

curl -k  \
-H "Accept: application/json" \
-H "Authorization: Bearer ${CIMITRA_API_SESSION_TOKEN}" \
-H "Cache-Control: no-cache" \
-X POST ${URL} \
-H "Content-Type: application/json" \
--data "${DATA}" -o ${CIMAGENT_FILE} 

echo ""
echo "-----------------------------------------------------------------------------"


declare -i CIMAGENT_FILE_EXISTS=`test -f ${CIMAGENT_FILE} ; echo $?`

if [ $CIMAGENT_FILE_EXISTS -ne 0 ]
then
echo ""
echo "Note: Could not Download the Cimitra Agent File"
return
fi

CALL_COMMAND "sudo chmod +x ${CIMAGENT_FILE}"

sudo chmod +x ${CIMAGENT_FILE}

cd ${TEMP_FILE_DIRECTORY}

if [ $DEBUG -eq 1 ]
then
sudo ./cimagent
else
	if [ $ROOT_USER -eq 1 ]
	then
	sudo ./cimagent 1> /dev/null 2> /dev/null 
	else
	sudo ./cimagent
	fi
fi

DOWNLOAD_FILE_STATE=`echo $?`

if [ $DOWNLOAD_FILE_STATE -ne 0 ]
then

	if [ $ROOT_USER -eq 1 ]
	then
	sudo rm ${CIMAGENT_FILE} 2> /dev/null
	else
	sudo rm ${CIMAGENT_FILE}
	fi

echo ""
echo "Error: The Cimitra Agent Could Not Be Downloaded"
echo ""
echo "NOTE: Generally this means that the server that hosts..."
echo ""
echo "... the Cimitra Server Docker Image needs more memory allocated"
echo ""
return 1

BASEURL="http://${CIMITRA_SERVER_API_ADDRESS}:${CIMITRA_SERVER_API_PORT}"

URL="${BASEURL}${ENDPOINT}" 

echo ""
echo "Process: Downloading the Cimitra Agent File (this may take a little bit...)"
echo ""
echo "-----------------------------------------------------------------------------"
echo ""

curl -k  \
-H "Authorization: Bearer ${CIMITRA_API_SESSION_TOKEN}" \
-X POST ${URL} \
-H "Content-Type: application/json" \
--data "${DATA}" -o ${CIMAGENT_FILE} 

echo ""
echo "-----------------------------------------------------------------------------"

else
echo ""
echo "Success: Downloaded the Cimitra Agent File"

fi

CALL_COMMAND "sudo chmod +x ${CIMAGENT_FILE}"

sudo chmod +x ${CIMAGENT_FILE}

if [ $DEBUG -eq 1 ]
then
sudo ./cimagent
else
	if [ $ROOT_USER -eq 1 ]
	then
	sudo ./cimagent 1> /dev/null 2> /dev/null 
	else
	sudo ./cimagent
	fi
fi

DOWNLOAD_FILE_STATE=`echo $?`

if [ $DOWNLOAD_FILE_STATE -eq 0 ]
then

if [ $SYSTEMD_INSTALL -eq 0 ]
then

CALL_COMMAND "sudo ./cimagent c"
sudo ./cimagent c

else

CALL_COMMAND "sudo ./cimagent c systemd"

sudo ./cimagent c systemd

fi

	if [ $DEBUG -eq 1 ]
	then
	cimitra stop
	cimitra start  &
	else

		if [ $ROOT_USER -eq 1 ]
		then
		{
		cimitra stop 2> /dev/null 
		cimitra start  &
		} 1> /dev/null 2> /dev/null
		else
		sudo cimitra stop 
		sudo cimitra start
		fi
	fi


else
echo ""
echo "Note: Could not Download the Cimitra Agent File"
echo ""
echo "Task: You may need to Download the Cimitra Agent"
echo ""
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

{
cimitra get gw & 1> /dev/null 2> /dev/null &
} 1> /dev/null 2> /dev/null 

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
cimitra get gw & 1> /dev/null 2> /dev/null &
} 1> /dev/null 2> /dev/null 

fi

{
cimitra get server & 1> /dev/null 2> /dev/null &
} 1> /dev/null 2> /dev/null 

{
cimitra get import & 1> /dev/null 2> /dev/null &
} 1> /dev/null 2> /dev/null 



}


function main()
{

CALL_INFO "1/5: Confirm/Install Docker"
CONFIRM_OR_INSTALL_DOCKER
CALL_INFO "2/5: Confirm/Install Docker Compose Utility"
CONFIRM_OR_INSTALL_DOCKER_COMPOSE
CALL_INFO "3/5: Confirm/Install Cimitra Server YAML File"
DOWNLOAD_CIMITRA_YAML_FILE
CALL_INFO "4/5: Download and Start Cimitra Server"
START_CIMITRA_DOCKER_CONTAINER

CALL_INFO "Waiting 10 Seconds for The Cimitra Server to Load"
CALL_COMMAND "sleep 10"
sleep 10
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

if [ $PROCEED_WITH_AGENT_INSTALL -eq 0 ]
then
ESTABLISH_CIMITRA_API_SESSION
fi


CALL_INFO "5/5: Download/Install Cimitra Agent"

if [ $PROCEED_WITH_AGENT_INSTALL -eq 0 ]
then
DOWNLOAD_AND_INSTALL_CIMITRA_AGENT
fi

		if [ $ROOT_USER -eq 1 ]
		then
		{
		sudo cimitra stop 1> /dev/null 2> /dev/null &
		} 1> /dev/null 2> /dev/null 
		else
		CALL_COMMAND "sudo cimitra stop"
		sudo cimitra stop
		fi

		

		if [ $ROOT_USER -eq 1 ]
		then
		CALL_COMMAND "cimitra start"
		{
		cimitra start & 1> /dev/null 2> /dev/null &
		} 1> /dev/null 2> /dev/null 

		else
		CALL_COMMAND "sudo cimitra start"

		sudo cimitra start

		fi

DOWNLOAD_CIMITRA_APIS

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

if [ $NUKE_DATA -eq 1 ]
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


