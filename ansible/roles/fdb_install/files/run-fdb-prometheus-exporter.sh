HOMEDIR=/home/fdb
DIR="$HOMEDIR/fdb-prometheus-exporter"

cd $HOMEDIR
if test -d "$DIR"; then
  echo "$DIR exists."
else
  wget https://golang.org/dl/go1.15.5.linux-amd64.tar.gz
  sudo tar -C /usr/local -xzf go1.15.5.linux-amd64.tar.gz
  git clone https://github.com/PierreZ/fdb-prometheus-exporter.git
fi
export PATH=$PATH:/usr/local/go/bin

cd $DIR
export FDB_API_VERSION=620
export FDB_CLUSTER_FILE=/etc/foundationdb/fdb.cluster

sudo pkill -f go
rm -rf prom-exporter.out
export PATH=$PATH:/usr/local/go/bin
go run main.go >> prom-exporter.out 2>&1 &
sleep 10
echo "Prometheus exporter running and metrics available on port 8080"
tail -n 50 prom-exporter.out