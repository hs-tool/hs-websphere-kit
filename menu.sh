#!/bin/bash
source "$(dirname "$0")/config.sh"

while true; do
    clear
echo ""
echo ""
echo ""
echo "*******************************************************"
echo "*      Developed by: Hafiz Syed MUhammad Usman        *"
echo "*******************************************************"
echo "*                                                     *"
echo "*  _____   _____ _______   _______                    *"
echo "* |  __ \ / ____|__   __| |__   __|                   *"
echo "* | |  | | |       | |       | | ___  __ _ _ __ ___   *"
echo "* | |  | | |       | |       | |/ _ \/ _\` | '_ \` _ \\  *"
echo "* | |__| | |____   | |       | |  __/ (_| | | | | | | *"
echo "* |_____/ \_____|  |_|       |_|\___|\__,_|_| |_| |_| *"
echo "*                                                     *"
echo "*******************************************************"
echo "*           Control Panel of the build                *"
echo "*******************************************************"
echo "*  Active Server: $SERVER_NAME"
echo "*******************************************************"
echo ""
echo ""
echo ""

    echo "+--------------------------+"
    echo "|      Control Panel       |"
    echo "|--------------------------+"
    echo "| 1.  Start MQ             |"
    echo "| 2.  Start Websphere      |"
    echo "| 3.  Stop Websphere       |"
    echo "| 4.  Set Java 8 SDK       |"
    echo "| 5.  Remove Temp Files    |"
    echo "| 6.  Check Space          |"
    echo "| 7.  Upgrade build        |"
    echo "| 8.  End to End Build     |"
    echo "| 9.  Clear Logs           |"
    echo "| 0.  Exit                 |"
    echo "+--------------------------+"

    read -p "Enter your choice (0-9): " choice

    case $choice in
        1) ./scripts/1-start-mq.sh ;;
        2) ./scripts/2-start-websphere.sh ;;
        3) ./scripts/6-stop-websphere.sh ;;
        4) ./scripts/4-configure-java-8.sh ;;
        5) ./scripts/5-remove-temp-files.sh ;;
        6) ./scripts/checkSpace.sh ;;
        7) ./scripts/7-upgrade-build.sh ;;
        8) ./scripts/e2e_build.sh ;;
        9) sudo ./scripts/clearLogs.sh ;;
        0) echo "Exiting..."; break ;;
        *) echo "Invalid option. Please enter a number between 0 and 9." ;;
    esac

    read -p "Press Enter to continue..."
done
