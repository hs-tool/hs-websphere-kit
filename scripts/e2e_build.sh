./scripts/1-start-mq.sh
if [ $? -eq 0 ]; then
    echo "1-start-mq.sh executed successfully"
else
    echo "1-start-mq.sh failed. Exiting."
    exit 1
fi
./scripts/2-start-websphere.sh
if [ $? -eq 0 ]; then
    echo "2-start-websphere.sh executed successfully"
else
    echo "2-start-websphere.sh failed. Exiting."
    exit 1
fi
./scripts/3-configure-java-7.sh
if [ $? -eq 0 ]; then
    echo "3-configure-java-7.sh executed successfully"
else
    echo "3-configure-java-7.sh failed. Exiting."
    exit 1
fi
./scripts/5-remove-temp-files.sh
if [ $? -eq 0 ]; then
    echo "5-remove-temp-files.sh executed successfully"
else
    echo "5-remove-temp-files.sh failed. Exiting."
    exit 1
fi
./scripts/7-upgrade-build.sh
if [ $? -eq 0 ]; then
    echo "7-upgrade-build.sh executed successfully"
else
    echo "7-upgrade-build.sh failed. Exiting."
    exit 1
fi
./scripts/4-configure-java-8.sh
./scripts/6-stop-websphere.sh
if [ $? -eq 0 ]; then
    echo "s6-stop-websphere.sh executed successfully"
else
    echo "s6-stop-websphere.sh failed. Exiting."
    exit 1
fi
./scripts/5-remove-temp-files.sh
if [ $? -eq 0 ]; then
    echo "5-remove-temp-files.sh executed successfully"
else
    echo "5-remove-temp-files.sh failed. Exiting."
    exit 1
fi
./scripts/2-start-websphere.sh
if [ $? -eq 0 ]; then
    echo "2-start-websphere.sh executed successfully"
else
    echo "2-start-websphere.sh failed. Exiting."
    exit 1
fi
echo "All scripts executed successfully"