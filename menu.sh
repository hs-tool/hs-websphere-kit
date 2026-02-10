#!/bin/bash


while true; do
    clear
echo ""
echo ""
echo ""
echo "*******************************************************"
echo "*      Aurthor: Hafiz Syed MUhammad Usman             *"
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
echo ""
echo ""
echo ""

    echo "+--------------------------+"
    echo "�      Control Panel       �"
    echo "�--------------------------�"
    echo "� 1.  Start MQ             �"
    echo "� 2.  Start Websphere      �"
    echo "� 3.  Stop Websphere       �"
    echo "� 4.  Set Java 7 SDK       �"
    echo "� 5.  Set Java 8 SDK       �"
    echo "� 6.  Remove Temp Files    �"
    echo "� 7.  Check Space          �"
    echo "� 8.  Upgrade build        �"
    echo "� 9.  End to End Build     �"
    echo "� 10. Clear Logs           �"
    echo "� 0.  Exit                 �"
    echo "+--------------------------+"

    read -p "Enter your choice (1-9): " choice

    case $choice in
        1) ./scripts/1-start-mq.sh ;;
        2) ./scripts/2-start-websphere.sh ;;
        3) ./scripts/6-stop-websphere.sh ;;
        4) ./scripts/3-configure-java-7.sh ;;
        5) ./scripts/4-configure-java-8.sh ;;
        6) ./scripts/5-remove-temp-files.sh ;;
        7) ./scripts/checkSpace.sh ;;
        8) ./scripts/7-upgrade-build.sh ;;
        9) ./scripts/e2e_build.sh ;;
        10) sudo ./scripts/clearLogs.sh ;;
        0) echo "Exiting..."; break ;;
        *) echo "Invalid option. Please enter a number between 1 and 9." ;;
    esac

    read -p "Press Enter to continue..."
done
