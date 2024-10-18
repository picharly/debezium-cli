#!/bin/bash

# Script to manage debezium connectors.
#
# @author picharly
# @version 1.0.0
#
# Must be into the same folder than JSON Connector files..

debeziumURL=http://localhost:8083

# Variables used for logic
allConnectors=($(curl -s ${debeziumURL}/connectors | tr -d '[]" ' | tr ',' '\n')) # Fetch all connectors and store them in an array
jsonFiles=($(grep -l '"connector.class"' *.json 2>/dev/null))
selection=
filename=
useFile=0
requiredCommands=("jq" "curl" "grep" "read") # List of required commands
missingCommands=()                           # Array to store missing commands

# Style variables
fontBold=$'\e[1m'
fontUnderline=$'\e[4m'
fontReset=$'\e[0m'
fontYellow=$'\e[93m'
fontWhite=$'\e[97m'
fontBlink=$'\e[5m'
fontRed=$'\e[31m'
fontGreen=$'\e[32m'
fontBlue=$'\e[34m'
fontOrange=$'\e[38;5;214m'

# Add a connector
#
# @param $1: the JSON file containing the connector configuration.
#
# Add a connector based on the JSON configuration in the file given as first
# argument. Then, check the connector status and wait for the user to press
# [Enter] before continuing with the rest of the script.
add_connector() {
    clear
    echo -e "${fontWhite}Adding connector '${fontReset}${fontYellow}$1${fontReset}${fontWhite}':${fontReset}"
    if ! [ ""$1"" == "" ]; then
        connectorName=$(grep -Po '"name"\s*:\s*"\K[^"]+' $1)
        curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" ${debeziumURL}/connectors/ -d @$1
        if [ $? -eq 0 ]; then
            enter_to_continue
            check_connector "${connectorName}"
        else
            echo -e "${fontRed}Cannot add connector '${fontReset}${fontYellow}${connectorName}${fontReset}${fontRed}' (${fontReset}${fontOrange}$1${fontReset}${fontRed}'. See error above.${fontReset}"
            enter_to_continue
        fi
    else
        echo -e "${fontRed}Connector name cannot be empty!${fontReset}"
        enter_to_continue
    fi
}

# Ask the user for a confirmation to delete a connector.
#
# @description
# Ask the user for a confirmation to delete a connector. If the user types 'y',
# return 1. If the user types 'n', return 0. Otherwise, ask again.
#
# @param $1: the action to perform.
# @param $2: the connector name.
#
# @return 1 if the user confirmed, 0 if the user refused.
ask_confirm() {
    read -p "${fontRed}Are you sure that you want to $1 connector '${fontReset}${fontYellow}$2${fontReset}${fontRed}' [y/n]? ${fontReset}" confirm
    confirm=$(echo -e "$confirm" | tr '[:upper:]' '[:lower:]')

    if [[ "$confirm" == "y" ]]; then
        echo -e "1"
    elif [[ "$confirm" == "n" ]]; then
        echo -e "0"
    else
        ask_confirm $1 $2
    fi
}

# Check the status of a connector.
#
# @description
# Check the status of a connector. If the connector name is empty, print an error
# message and exit.
#
# @param $1: the connector name.
#
# @example
# check_connector "my-connector"
check_connector() {
    clear
    echo -e "${fontWhite}Checking connector '${fontReset}${fontYellow}$1${fontReset}':${fontReset}"
    if ! [ ""$1"" == "" ]; then
        curl -s ${debeziumURL}/connectors/$1/status | jq
    else
        echo -e "${fontRed}Connector name cannot be empty!${fontReset}"
    fi
    enter_to_continue
}

# Check if all the required commands are available.
#
# This function checks if all the commands in the requiredCommands array are
# available. If any of the commands are missing, it will print an error message
# and exit the script.
check_requirements() {
    # Check each command
    for cmd in "${requiredCommands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missingCommands+=("$cmd")
        fi
    done

    # If there are missing commands, show error and exit
    if [ ${#missingCommands[@]} -ne 0 ]; then
        plural=""
        if [ ${#missingCommands[@]} -gt 1 ]; then
            echo -e "\n${fontRed}[ERROR]${fontWhite} The following required commands are missing:${fontReset}"
            plural="s"
        else
            echo -e "\n${fontRed}[ERROR]${fontWhite} The following required command is missing:${fontReset}"
        fi
        for cmd in "${missingCommands[@]}"; do
            echo -e "  - ${fontOrange}${cmd}${fontReset}"
        done
        echo -e "${fontYellow}${fontBold}\nPlease install the missing command${plural} and run the script again.${fontReset}\n"
        exit 1
    fi
}

#
# Delete a connector.
#
# @description
# Deletes a connector specified by the connector name. If the connector name is
# empty, prints an error message. If deletion fails, an error message is displayed.
#
# @param $1: the connector name.
#
# @example
# delete_connector "my-connector"
delete_connector() {
    clear
    echo -e "${fontWhite}Deleting connector '${fontReset}${fontYellow}$1${fontReset}':${fontReset}"
    if ! [ ""$1"" == "" ]; then
        curl -X DELETE ${debeziumURL}/connectors/$1
        if ! [ $? -eq 0 ]; then
            echo -e "${fontRed}Cannot delete connector '${fontReset}${fontYellow}$1${fontReset}'. See error above.${fontReset}"
            if [ "$2" == "" ] || [ "$2" == "1" ]; then
                enter_to_continue
            fi
        else
            echo -e "${fontRed}Connector deleted${fontReset}"
        fi
    else
        echo -e ${fontRed}"Connector name cannot be empty!${fontReset}"
        enter_to_continue
    fi
}

# Pause execution and wait for the user to press [Enter].
#
# The function echoes a newline, then waits for the user to press [Enter] before
# continuing with the rest of the script.
enter_to_continue() {
    echo -e "\n\n"
    read -p "${fontWhite}${fontBlink}[Enter] to continue${fontReset}"
}

# Check if a connector exists.
#
# @description
# Check if a connector exists. Iterates over the list of all connectors and checks
# if the given connector name matches any of the names in the list. If a match is
# found, then the function returns 1, otherwise it returns 0.
#
# @param $1: the connector name to check.
#
# @example
# if [ "$(is_connector_exists "my-connector")" -eq 1 ]; then
#     echo "Connector exists"
# fi
is_connector_exists() {
    exists=0
    for i in "${!allConnectors[@]}"; do
        if [ "$1" == "${allConnectors[$i]}" ]; then
            exists=1
        fi
    done
    echo -e $exists
}

#
# Restart a connector.
#
# @description
# Restart a connector specified by the connector name. If the connector name is
# empty, prints an error message. If restart fails, an error message is displayed.
#
# @param $1: the connector name.
#
# @example
# restart_connector "my-connector"
restart_connector() {
    clear
    echo -e "${fontWhite}Restarting connector '${fontReset}${fontYellow}$1${fontReset}':${fontReset}"
    if ! [ ""$1"" == "" ]; then
        curl -X POST ${debeziumURL}/connectors/$1/restart
        if ! [ $? -eq 0 ]; then
            echo -e "${fontRed}Cannot restart connector '${fontReset}${fontYellow}$1${fontReset}'. See error above.${fontReset}"
            enter_to_continue
        fi
    else
        echo -e "${fontRed}Connector name cannot be empty!${fontReset}"
        enter_to_continue
    fi
}

#
# Resume a connector.
#
# @description
# Resume a connector specified by the connector name. If the connector name is
# empty, prints an error message. If resume fails, an error message is displayed.
#
# @param $1: the connector name.
#
# @example
# resume_connector "my-connector"
resume_connector() {
    clear
    echo -e "${fontWhite}Resuming connector '${fontReset}${fontYellow}$1${fontReset}':${fontReset}"
    if ! [ ""$1"" == "" ]; then
        curl -X PUT ${debeziumURL}/connectors/$1/resume
        if ! [ $? -eq 0 ]; then
            echo -e "${fontRed}Cannot resume connector '${fontReset}${fontYellow}$1${fontReset}'. See error above.${fontReset}"
            enter_to_continue
        fi
    else
        echo -e "${fontRed}Connector name cannot be empty!${fontReset}"
        enter_to_continue
    fi
}

#
# Stop a connector.
#
# @description
# Stop a connector specified by the connector name. If the connector name is
# empty, prints an error message. If stop fails, an error message is displayed.
#
# @param $1: the connector name.
#
# @example
# stop_connector "my-connector"
stop_connector() {
    clear
    echo -e "${fontWhite}Stopping connector '${fontReset}${fontYellow}$1${fontReset}':${fontReset}"
    if ! [ ""$1"" == "" ]; then
        curl -X PUT ${debeziumURL}/connectors/$1/pause
        if ! [ $? -eq 0 ]; then
            echo -e "${fontRed}Cannot stop connector '${fontReset}${fontYellow}$1${fontReset}'. See error above.${fontReset}"
            enter_to_continue
        fi
    else
        echo -e "${fontRed}Connector name cannot be empty!${fontReset}"
        enter_to_continue
    fi
}

# Update a connector.
#
# @description
# Update a connector specified by the connector name. If the connector name is
# empty, prints an error message. If update fails, an error message is displayed.
#
# @param $1: the JSON file containing the connector configuration.
#
# @example
# update_connector "my-connector.json"
update_connector() {
    clear
    echo -e "${fontWhite}Updating connector '${fontReset}${fontYellow}$1${fontReset}${fontWhite}':${fontReset}"
    if ! [ ""$1"" == "" ]; then
        connectorName=$(grep -Po '"name"\s*:\s*"\K[^"]+' $1)
        curl -i -X PUT -H "Content-Type:application/json" --data "$(jq '.config' $1)" ${debeziumURL}/connectors/${connectorName}/config
        if [ $? -eq 0 ]; then
            enter_to_continue
            check_connector "${connectorName}"
        else
            echo -e "${fontRed}Cannot update connector '${fontReset}${fontYellow}${connectorName}${fontReset}${fontRed}' (${fontReset}${fontOrange}$1${fontReset}${fontRed}'. See error above.${fontReset}"
            enter_to_continue
        fi
    else
        echo -e "${fontRed}Connector name cannot be empty!${fontReset}"
        enter_to_continue
    fi
}

#
# Update the list of all connectors and JSON configuration files.
#
# @description
# Fetches the current list of connectors from the Debezium URL and updates the
# allConnectors array. Also, searches for JSON files containing the key
# "connector.class" and updates the jsonFiles array.
#
update_connectors() {
    allConnectors=($(curl -s ${debeziumURL}/connectors | tr -d '[]" ' | tr ',' '\n'))
    jsonFiles=($(grep -l '"connector.class"' *.json 2>/dev/null))
}

#
# Display the main menu.
#
# @description
# Display the main menu with two options: add a connector or manage a connector.
# If a connector is selected, it calls menu_action to display its menu.
# If the add a connector option is selected, it calls menu_add_connector to display its menu.
#
menu_main() {
    # Display the menu
    update_connectors
    clear
    echo -e "\n${fontWhite}${fontBold}${fontUnderline}Debezium / Kafka Connect Manager:${fontReset}\n"
    minChoice=1
    if [ ${#jsonFiles[@]} -gt 0 ]; then
        if [ ${#allConnectors[@]} -gt 0 ]; then
            echo -e "${fontYellow}0.${fontReset} Add/Update a connector"
        else
            echo -e "${fontYellow}0.${fontReset} Add a connector"
        fi
        minChoice=0
    fi
    for i in "${!allConnectors[@]}"; do
        connectorStatus=$(curl -s "${debeziumURL}/connectors/${allConnectors[$i]}/status" | grep -Po '"state"\s*:\s*"\K[^"]+' | head -n 1)
        if [ "${connectorStatus,,}" == "running" ]; then
            connectorStatus="${fontGreen}${connectorStatus}${fontReset}"
        elif [ "${connectorStatus,,}" == "paused" ]; then
            connectorStatus="${fontYellow}${connectorStatus}${fontReset}"
        elif [ "${connectorStatus,,}" == "failed" ]; then
            connectorStatus="${fontRed}${connectorStatus}${fontReset}"
        elif [ "${connectorStatus,,}" == "unassigned" ]; then
            connectorStatus="${fontBlue}${connectorStatus}${fontReset}"
        elif [ "${connectorStatus,,}" == "destroyed" ]; then
            connectorStatus="${fontOrange}${connectorStatus}${fontReset}"
        fi
        echo -e "${fontYellow}$((i + 1)).${fontReset} Manage '${fontWhite}${allConnectors[$i]}${fontReset}' - state: ${fontBlue}${connectorStatus}${fontReset}"
    done
    echo -e "${fontYellow}$((${#allConnectors[@]} + 1)).${fontReset} Quit"

    # Read user input
    echo ""
    read -p "${fontBlue}What do you want to do? ${fontReset}" choice

    # Validate input
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt $minChoice ] || [ "$choice" -gt "$((${#allConnectors[@]} + 1))" ]; then
        echo -e "${fontRed}Invalid selection.${fontReset}"
        selection=
        menu_main
    else

        if [ ${choice} -gt 0 ] && [ "${choice}" -lt "$((${#allConnectors[@]} + 1))" ]; then
            # Get the selected connector name
            selection="${allConnectors[$((choice - 1))]}"
            menu_action
        elif [ "${choice}" -eq "$((${#allConnectors[@]} + 1))" ]; then
            exit 0
        else
            menu_add_connector
        fi
    fi
}

# Display the menu for the selected connector
#
# @description
# This menu provides the following options:
# - Resume the connector if it is paused
# - Stop/Pause the connector if it is running
# - Restart the connector
# - Delete the connector
# - View the status details of the connector
# - Go back to the main menu
menu_action() {
    # Display the menu
    update_connectors
    clear
    currentState=$(curl -s "${debeziumURL}/connectors/${allConnectors[$i]}/status" | grep -Po '"state"\s*:\s*"\K[^"]+' | head -n 1)
    connectorStatus=${currentState}
    if [ "${connectorStatus,,}" == "running" ]; then
        connectorStatus="${fontGreen}${connectorStatus}${fontReset}"
    elif [ "${connectorStatus,,}" == "paused" ]; then
        connectorStatus="${fontYellow}${connectorStatus}${fontReset}"
    elif [ "${connectorStatus,,}" == "failed" ]; then
        connectorStatus="${fontRed}${connectorStatus}${fontReset}"
    elif [ "${connectorStatus,,}" == "unassigned" ]; then
        connectorStatus="${fontBlue}${connectorStatus}${fontReset}"
    elif [ "${connectorStatus,,}" == "destroyed" ]; then
        connectorStatus="${fontOrange}${connectorStatus}${fontReset}"
    fi
    echo -e "${fontWhite}${fontBold}Selected connector:${fontReset} '${fontWhite}${selection}${fontReset}'"
    echo -e "${fontWhite}${fontBold}Current state:${fontReset} '${fontBlue}${connectorStatus}${fontReset}'"
    echo ""
    if [ "${currentState,,}" == "paused" ]; then
        echo -e "${fontYellow}1.${fontReset} Resume"
    else
        echo -e "${fontYellow}1.${fontReset} Stop/Pause"
    fi
    echo -e "${fontYellow}2.${fontReset} Restart"
    echo -e "${fontYellow}3.${fontReset} Delete"
    echo -e "${fontYellow}4.${fontReset} Status details"
    echo -e "${fontYellow}5.${fontReset} Back"

    # Read user input
    echo ""
    read -p "${fontBlue}What is your choice? ${fontReset}" choice

    # Validate input
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt 5 ]; then
        echo -e "Invalid selection."
        menu_action
    else

        # Execute action
        echo -e "\n\n"
        if [ ${choice} -eq 1 ]; then
            if [ "${currentState,,}" == "paused" ]; then
                resume_connector "${selection}"
            else
                stop_connector "${selection}"
            fi
            menu_action
        elif [ ${choice} -eq 2 ]; then
            restart_connector "${selection}"
            menu_action
        elif [ ${choice} -eq 3 ]; then
            if [ "$(ask_confirm delete "${selection}")" -eq 1 ]; then
                delete_connector "${selection}"
                selection=
                menu_main
            else
                menu_action
            fi
        elif [ ${choice} -eq 4 ]; then
            check_connector "${selection}"
            menu_action
        else
            menu_main
        fi

    fi

}

# Description:
# This function displays a menu to the user to add or replace a connector.
# The menu displays a list of available connector configuration files and
# for each one, it shows if the connector already exists or not.
# The user can select a connector and choose to add or replace it.
# If the connector already exists, the user is asked for confirmation before
# replacing it.
# If the user selects 0, the function returns to the main menu.
menu_add_connector() {
    # Display the menu
    update_connectors
    listUpdates=("dummy")
    clear
    echo -e "${fontWhite}${fontBold}${fontUnderline}Add/Replace a connector:${fontReset}"
    echo ""
    echo -e "${fontYellow}0.${fontReset} Back"
    for i in "${!jsonFiles[@]}"; do
        connectorName=$(grep -Po '"name"\s*:\s*"\K[^"]+' ${jsonFiles[$i]})
        exists=$(is_connector_exists "${connectorName}") #$(curl -s "${debeziumURL}/connectors/${allConnectors[$i]}/status" | grep -Po '"state"\s*:\s*"\K[^"]+' | head -n 1)
        if [ ${exists} -gt 0 ]; then
            exists="Replace/Update"
            listUpdates+=(${connectorName})
        else
            exists="Add"
            listUpdates+=("")
        fi
        echo -e "${fontYellow}$((i + 1)).${fontReset} ${exists} '${fontBlue}${connectorName}${fontReset}' (${jsonFiles[$i]})"
    done

    # Read user input
    echo ""
    read -p "${fontBlue}Which connector? ${fontReset}" choice

    # Validate input
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt "${#jsonFiles[@]}" ]; then
        echo -e "Invalid selection."
        menu_add_connector
    else
        if [ ${choice} -gt 0 ]; then
            # Get the selected connector name
            selection="${jsonFiles[$((choice - 1))]}"
            if [ ${#listUpdates[${choice}]} -gt 0 ]; then
                echo -e "\n\n"
                if [ "$(ask_confirm update "${listUpdates[${choice}]}")" -eq 1 ]; then
                    update_connector "${selection}"
                    menu_main
                else
                    menu_add_connector
                fi
            else
                add_connector "${selection}"
                menu_main
            fi

        else
            menu_main
        fi
    fi
}

# 1. Check requirements
check_requirements

# 2. Show main menu
menu_main
