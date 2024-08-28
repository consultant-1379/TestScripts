#########################################
## Name: cENM Daily Health Check Run   ##
## By: ERAHCHU                         ##
## Last updated:25-June-2020           ##
#########################################
echo -e "\e[0;34m Version: 1.1 \e[0m"

dt1=`date "+%Y-%m-%d"`
rv_dailychecks_tmp_file="/ericsson/enm/dumps/.rv_dailychecks_tmp_file.log"
CLI_APP="/opt/ericsson/enmutils/bin/cli_app"
cENM_id=`/usr/local/bin/kubectl --kubeconfig /root/.kube/config get ingress --all-namespaces | egrep ui|awk '{print $1}'`
echo -e "\e[0;32m *** check cluster info is correct *** \e[0m"
echo -e "\e[0;32m--------------------------------------\e[0m"
kubectl cluster-info
echo

echo -e "\e[0;32m *** check cluster control plane *** \e[0m"
echo -e "\e[0;32m--------------------------------------\e[0m"
kubectl get componentstatuses
echo

echo -e "\e[0;32m *** check worker nodes states *** \e[0m"
echo -e "\e[0;32m--------------------------------------\e[0m"
kubectl get nodes -n ${cENM_id}
echo

echo -e "\e[0;32m *** check LVS nodes Tainted & Labelled *** \e[0m"
echo -e "\e[0;32m--------------------------------------\e[0m"
kubectl describe nodes -n ${cENM_id}| egrep "Taint|Hostname" | grep -A 1 routing
echo

echo -e "\e[0;32m *** check statefulsets status *** \e[0m"
echo -e "\e[0;32m--------------------------------------\e[0m"
kubectl get statefulsets -n ${cENM_id}
echo

echo -e "\e[0;32m *** verify no running JOBS *** \e[0m"
echo -e "\e[0;32m--------------------------------------\e[0m"
kubectl get jobs -n ${cENM_id}
echo

echo -e "\e[0;32m *** verify no running cronjobs *** \e[0m"
echo -e "\e[0;32m--------------------------------------\e[0m"
kubectl get cronjobs -n ${cENM_id}
echo

echo -e "\e[0;32mList of Pods in NOT-RUNNING state \e[0m"
echo -e "\e[0;32m---------------------------------\e[0m"
kubectl get pods -n ${cENM_id}|egrep -v '1/1|2/2|3/3|4/4|Completed'
echo

echo -e "\e[0;32mList of Pods RESTARTED latest \e[0m"
echo -e "\e[0;32m---------------------------------\e[0m"
kubectl get pods --sort-by=.status.containerStatuses[0].restartCount -n ${cENM_id} | sort -k3|awk '$4>0'|grep -v NAME
echo

echo -e "\e[0;32mList of Pods RESTARTED More Details \e[0m"
echo -e "\e[0;32m---------------------------------\e[0m"
kubectl get pods -n ${cENM_id} -o custom-columns=NAME:.status.containerStatuses[*].name,Count:.status.containerStatuses[*].restartCount,INFO:.status.containerStatuses[*].lastState|awk '$2!="0,0,0,0" && $2!="0,0,0" && $2!="0,0" && $2!="0"'
echo

echo -e "\e[0;32mCurrent NEO4J Status \e[0m"
echo -e "\e[0;32m---------------------------------\e[0m"
kubectl -n ${cENM_id} exec `kubectl get pods -n ${cENM_id}|grep -w neo4j-[0-2]|head -1|awk '{print $1}'` -it -- bash -c "/var/lib/neo4j/bin/cypher-shell -u neo4j -p Neo4jadmin123 -a bolt://neo4j:7687 'CALL dbms.cluster.overview()';"
echo

echo -e "\e[0;32mRecent NEO4J Garbage Collection \e[0m"
echo -e "\e[0;32m---------------------------------\e[0m"
kubectl -n ${cENM_id} exec `kubectl get pods -n ${cENM_id}|grep -w neo4j-[0-2]|head -1|awk '{print $1}'` -it -- bash -c "egrep GC --colour /var/lib/neo4j/logs/debug.log | grep -v DiagnosticsManager"
echo

echo -e "\e[0;32mCurrent Number of Document stored in SOLR: \e[0m"
echo -e "\e[0;32m---------------------------------\e[0m"
kubectl -n ${cENM_id} exec `kubectl get pods -n ${cENM_id}|grep -w cmserv|tail -1|awk '{print $1}'` -it -- bash -c "curl -s 'http://solr:8983/solr/admin/cores?action=STATUS&core=collection1&wt=json&indent=true&memory=true'|egrep 'name|numDocs'"
echo
kubectl exec -n ${cENM_id} `kubectl get pods -n ${cENM_id}|grep -w cmserv|tail -1|awk '{print $1}'` -it -- bash -c "curl -s 'http://solr:8983/solr/admin/cores?action=STATUS&core=cm_events_nbi&wt=json&indent=true&memory=true'|egrep 'name|numDocs'"
echo
kubectl exec -n ${cENM_id} `kubectl get pods -n ${cENM_id}|grep -w cmserv|tail -1|awk '{print $1}'` -it -- bash -c "curl -s 'http://solr:8983/solr/admin/cores?action=STATUS&core=cm_history&wt=json&indent=true&memory=true'|egrep 'name|numDocs'"
echo

