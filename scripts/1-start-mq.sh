password="mqmuser"
su -c "cd /opt/mqm/bin/ && ./strmqm INT_QM" mqmuser <<EOF
$password
EOF
ps -ef | grep websphere
read -p "Enter First port number to kill: " portNumber

if [[ $portNumber =~ ^[0-9]+$ ]]; then
    ps -ef | grep websphere | grep $portNumber | awk '{print $2}' | xargs kill -9
    echo "Process using port $portNumber killed."
else
    echo "Invalid port number. Please enter a valid numeric port number."
fi
read -p "Enter Second port number to kill: " portNumber

if [[ $portNumber =~ ^[0-9]+$ ]]; then
    ps -ef | grep websphere | grep $portNumber | awk '{print $2}' | xargs kill -9
    echo "Process using port $portNumber killed."
else
    echo "Invalid port number. Please enter a valid numeric port number."
fi
cd /home/wasadmin/DCT